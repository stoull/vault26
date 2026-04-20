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
    private let clientService: MQTTClientService
    private let processor: MQTTMessageProcessor
    private let logger = Logger(label: "MQTTService")
    private var listenerTask: Task<Void, Never>? = nil

    init(dbManager: DatabaseManager? = nil) throws {
        self.clientService = try MQTTClientService()
        self.processor = MQTTMessageProcessor(dbManager: dbManager)
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
            self.logger.info("MQTT service subscribed topics: \(config.mqttTopics)")
        } catch {
            logger.error("Failed to subscribe MQTT topic: \(config.mqttTopics) error: \(error)")
            throw error
        }

        // 开始监听并转发成功的消息给 processor
        let task = await clientService.startListening { result in
            switch result {
            case .success(let message):
                let topic = message.topicName
                if let payloadString = message.payload.getString(at: message.payload.readerIndex,
                                                                 length: message.payload.readableBytes,
                                                                 encoding: .utf8) {
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
                if let payloadString = message.payload.getString(at: message.payload.readerIndex,
                                                                 length: message.payload.readableBytes,
                                                                 encoding: .utf8) {
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
}
