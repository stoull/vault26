//
//  File.swift
//  MQTTClientServer
//
//  Created by Hut on 2026/4/10.
//

import Foundation
import MQTTNIO
import Fluent
import NIO
import NIOSSL
import Logging

/// 负责：协调 MQTT 客户端和消息处理器
actor MQTTService {
    struct ServiceStatus: Sendable {
        let isListening: Bool
        let subscribeAck: String?
        let clientId: String
        let subscribedTopics: [String]
        let receivedMessages: Int
        let lastMessageTopic: String?
        let lastMessageAtISO8601: String?
        let onlineDevices: Int?
        let totalDevices: Int?
    }

    struct BrokerStatus: Sendable {
        let isListening: Bool
        let clientId: String
        let subscribedTopics: [String]
        let receivedMessages: Int
        let connectedClients: Int?
        let totalClients: Int?
        let receivedMessagesOnBroker: Int?
        let brokerUptime: String?
        let lastSysMessageAtISO8601: String?
        let sysMetrics: [String: String]
    }

    private let clientService: MQTTClientService
    private let processor: MQTTMessageProcessor
    private let dbManager: DatabaseManager?
    private let logger = Logger(label: "MQTTService")
    private var listenerTask: Task<Void, Never>? = nil
    private var receivedMessages: Int = 0
    private var lastMessageTopic: String? = nil
    private var lastMessageAt: Date? = nil
    private var lastSysMessageAt: Date? = nil
    private var subscribedTopics: [String] = []
    private var sysMetrics: [String: String] = [:]

    init(dbManager: DatabaseManager? = nil) throws {
        self.clientService = try MQTTClientService()
        self.processor = MQTTMessageProcessor(dbManager: dbManager)
        self.dbManager = dbManager
    }

    /// 连接并开始订阅与监听
    func start() async throws {
        do {
            try await clientService.start()
        } catch {
            logger.error("Failed to start MQTT client service: \(error)")
            throw error
        }

        // 订阅主题
        do {
            try await clientService.subscribe(to: config.mqttTopics)
            self.subscribedTopics = config.mqttTopics
            self.logger.info("MQTT service subscribed topics: \(config.mqttTopics)")
        } catch {
            logger.error("Failed to subscribe MQTT topic: \(config.mqttTopics) error: \(error)")
            throw error
        }

        // Optional: subscribe broker system metrics. If broker/ACL does not allow $SYS,
        // keep service running and expose empty broker metrics.
        let sysTopic = config.mqttSystemTopics // "$SYS/#"
        if let firstTopic = sysTopic.first,
           !self.subscribedTopics.contains(firstTopic) {
            do {
                try await clientService.subscribe(to: config.mqttSystemTopics)
                self.subscribedTopics.append(contentsOf: config.mqttSystemTopics)
                self.logger.info("MQTT service subscribed broker metrics topic: \(sysTopic)")
            } catch {
                self.logger.warning("Skip $SYS subscribe due to broker/ACL restrictions: \(error)")
            }
        }

        // 开始监听并转发成功的消息给 processor
        let task = await clientService.startListening { result in
            switch result {
            case .success(let message):
                let topic = message.topicName
                self.recordInboundMessage(topic: topic)
                if let payloadString = message.payload.getString(
                    at: message.payload.readerIndex,
                    length: message.payload.readableBytes,
                    encoding: .utf8
                ) {
                    if topic.hasPrefix("$SYS/") {
                        // self.logger.info("MQTTService: received $SYS topic=\(topic) payload=\(payloadString)")
                        self.recordSysMetric(topic: topic, payload: payloadString)
                        return
                    }
                    await self.processor.process(topic: topic, payloadString: payloadString)
                } else {
                    self.logger.warning("Failed to decode payload for topic: \(topic)")
                }
            case .failure(let error):
                self.logger.error("MQTT receive error: \(error)")
            }
        }
        self.logger.info("MQTT listening on topics: \(config.MQTT_HOST):\(config.MQTT_PORT)")
        self.listenerTask = task
    }

    func publish(topic: String, payload: String) async throws {
        try await clientService.publish(topic: topic, payload: payload)
    }

    func onlineDevicesCount() async -> Int? {
        guard let dbManager else { return nil }
        do {
            return try await EdgeDevice.query(on: dbManager.db())
                .filter(\.$status, .equal, "online")
                .count()
        } catch {
            logger.warning("Failed to query online devices count: \(error)")
            return nil
        }
    }

    func serviceStatus() async -> ServiceStatus {
        let isListening = await clientService.isListening()
        let subscribeAck = await clientService.subscribeAckDescription()
        let clientId = await clientService.currentClientId()

        var onlineDevices: Int? = nil
        var totalDevices: Int? = nil
        if let dbManager {
            do {
                onlineDevices = try await EdgeDevice.query(on: dbManager.db())
                    .filter(\.$status, .equal, "online")
                    .count()
                totalDevices = try await EdgeDevice.query(on: dbManager.db()).count()
            } catch {
                logger.warning("Failed to query MQTT service device counters: \(error)")
            }
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let lastMessageAtISO8601 = lastMessageAt.map { formatter.string(from: $0) }

        return ServiceStatus(
            isListening: isListening,
            subscribeAck: subscribeAck,
            clientId: clientId,
            subscribedTopics: subscribedTopics,
            receivedMessages: receivedMessages,
            lastMessageTopic: lastMessageTopic,
            lastMessageAtISO8601: lastMessageAtISO8601,
            onlineDevices: onlineDevices,
            totalDevices: totalDevices
        )
    }

    func brokerStatus() async -> BrokerStatus {
        let isListening = await clientService.isListening()
        let clientId = await clientService.currentClientId()

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let lastSysMessageAtISO8601 = lastSysMessageAt.map { formatter.string(from: $0) }

        let connectedClients = intMetricValue(for: [
            "$SYS/broker/clients/connected",
            "$SYS/broker/clients/active"
        ])
        let totalClients = intMetricValue(for: [
            "$SYS/broker/clients/total"
        ])
        let receivedMessagesOnBroker = intMetricValue(for: [
            "$SYS/broker/messages/received"
        ])
        let brokerUptime = stringMetricValue(for: [
            "$SYS/broker/uptime"
        ])

        return BrokerStatus(
            isListening: isListening,
            clientId: clientId,
            subscribedTopics: subscribedTopics,
            receivedMessages: receivedMessages,
            connectedClients: connectedClients,
            totalClients: totalClients,
            receivedMessagesOnBroker: receivedMessagesOnBroker,
            brokerUptime: brokerUptime,
            lastSysMessageAtISO8601: lastSysMessageAtISO8601,
            sysMetrics: sysMetrics
        )
    }
    
    // Diagnostics helpers
    func listenerStatus() async -> String {
        let isListening = await clientService.isListening()
        let ack = await clientService.subscribeAckDescription() ?? "<no-ack>"
        let clientId = await clientService.currentClientId()
        return "listening=\(isListening) subscribeAck=\(ack) clientId=\(clientId)"
    }

    func restartListener() async {
        await clientService.stopListening()
        let task = await clientService.startListening { result in
            switch result {
            case .success(let message):
                let topic = message.topicName
                self.recordInboundMessage(topic: topic)
                if let payloadString = message.payload.getString(
                    at: message.payload.readerIndex,
                    length: message.payload.readableBytes,
                    encoding: .utf8
                ) {
                    if topic.hasPrefix("$SYS/") {
                        self.recordSysMetric(topic: topic, payload: payloadString)
                        return
                    }
                    await self.processor.process(topic: topic, payloadString: payloadString)
                } else {
                    self.logger.warning("Failed to decode payload for topic: \(topic)")
                }
            case .failure(let error):
                self.logger.error("MQTT receive error: \(error)")
            }
        }
        self.listenerTask = task
    }

    private func recordInboundMessage(topic: String) {
        receivedMessages += 1
        lastMessageTopic = topic
        lastMessageAt = Date()
    }

    private func recordSysMetric(topic: String, payload: String) {
        sysMetrics[topic] = payload
        lastSysMessageAt = Date()
    }

    private func intMetricValue(for keys: [String]) -> Int? {
        for key in keys {
            guard let raw = sysMetrics[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
                continue
            }
            if let value = Int(raw) {
                return value
            }
        }
        return nil
    }

    private func stringMetricValue(for keys: [String]) -> String? {
        for key in keys {
            guard let raw = sysMetrics[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
                continue
            }
            return raw
        }
        return nil
    }
}
