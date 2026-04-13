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

/// 负责：1. 订阅 MQTT 话题并写入 DB  2. 提供 publish 方法给 HTTP 路由调用
actor MQTTService {
    let client: MQTTClient
    private let logger = Logger(label: "MQTTService")
    
    // 数据库管理器（用于保存数据）
    private let dbManager: DatabaseManager?
    
    // 自定义事件循环组（如果需要独立于应用其他部分）
    // private let eventLoopGroup: MultiThreadedEventLoopGroup

    init() throws {
        // 创建事件循环组
        // self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        // 配置 TLS
        var tlsConfiguration: TLSConfiguration? = nil
        if (config.mqttEnableTSL) {
            tlsConfiguration = TLSConfiguration.makeClientConfiguration()
            tlsConfiguration!.certificateVerification = .none  // .none .noHostnameVerification 仅用于测试，生产环境不推荐
        }
        
        // 创建 MQTT 客户端配置
        let clientConfiguration = MQTTClient.Configuration(
            keepAliveInterval: .seconds(config.mqttKeepAliveInterval),
            userName: config.MQTT_USERNAME,
            password: config.MQTT_PASSWORD,
            tlsConfiguration: tlsConfiguration.map { .niossl($0) }
        )
        
        self.client = MQTTClient(
            host: config.MQTT_HOST,
            port: config.MQTT_PORT,
            identifier: config.mqttClientId,
            eventLoopGroupProvider: .shared(MultiThreadedEventLoopGroup.singleton), // System.coreCount个
            logger: logger,
            configuration: clientConfiguration
        )

        // 默认不注入 DatabaseManager，保持与现有行为一致
        self.dbManager = nil
    }

    /// 连接并开始订阅
    func start() async throws {
        try await client.connect()
        
        logger.info("已连接到 MQTT Broker: \(config.MQTT_HOST):\(config.MQTT_PORT)")
        
        // 订阅多个主题
        let subscriptions = config.mqttTopics.map { topic in
            MQTTSubscribeInfo(topicFilter: topic, qos: .atLeastOnce)
        }
        
        // assign the result to `_` to avoid 'Result of call is unused' warning
        _ = try await client.subscribe(to: subscriptions)

        // 开始监听消息（后台任务）
        Task { await self.listenForMessages() }
    }

    /// 向指定话题发布消息
    func publish(topic: String, payload: String) async throws {
        var buffer = ByteBufferAllocator().buffer(capacity: payload.utf8.count)
        buffer.writeString(payload)
        try await client.publish(
            to: topic,
            payload: buffer,
            qos: .atLeastOnce
        )
        logger.info("Published to \(topic): \(payload)")
    }

    // MARK: - Private

    private func listenForMessages() async {
        for await result in client.createPublishListener() {
            switch result {
            case .success(let message):
                await handleMessage(message)
            case .failure(let error):
                logger.error("Failed to receive publish message: \(error)")
            }
        }
    }

    private func handleMessage(_ message: MQTTPublishInfo) async {
        let topic = message.topicName
        guard let payloadString = message.payload.getString(
            at: message.payload.readerIndex,
            length: message.payload.readableBytes,
            encoding: .utf8
        ) else { return }

        logger.info("Received [\(topic)]: \(payloadString)")

        // 解析 JSON
        guard let data = payloadString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            logger.warning("Invalid JSON on topic \(topic)")
            return
        }

        
        if (self.dbManager != nil) {
            let record = SensorData(
                topic: topic,
                payload: payloadString,
                temperature: json["temperature"] as? Double,
                humidity:    json["humidity"]    as? Double
            )

            do {
                if let dbManager = self.dbManager {
                    try await dbManager.withRetry(maxAttempts: 3, delay: .seconds(2)) {
                        try await record.save(on: dbManager.db())
                    }
                    let idString = record.id?.uuidString ?? "<no-id>"
                    logger.info("Saved [\(idString)] temp=\(String(describing: record.temperature))")
                } else {
                    logger.warning("No DatabaseManager available: skipping save for topic=\(topic)")
                }
             } catch {
                 logger.error("Save failed after retries: \(error)")
             }
        }
        
     }
 }
