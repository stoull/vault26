import Foundation
import MQTTNIO
import NIO
import NIOSSL
import Logging

/// 仅负责 MQTT 客户端相关逻辑：连接、订阅、发布与监听
actor MQTTClientService {
    let client: MQTTClient
    private let logger = Logger(label: "MQTTClientService")
    private var listenerTask: Task<Void, Never>? = nil
    private var lastSubscribeAckDescription: String? = nil
    private let clientIdUsed: String

    init() throws {
        // ensure client id is reasonably unique to avoid collisions with other clients
        let pid = ProcessInfo.processInfo.processIdentifier
        let shortUUID = UUID().uuidString.split(separator: "-").first ?? ""
        self.clientIdUsed = "\(config.mqttClientId)-\(pid)-\(shortUUID)"
        // 配置 TLS
        var tlsConfiguration: TLSConfiguration? = nil
        if (config.mqttEnableTSL) {
            tlsConfiguration = TLSConfiguration.makeClientConfiguration()
            tlsConfiguration!.certificateVerification = .none // 测试用
        }

        let clientConfiguration = MQTTClient.Configuration(
            keepAliveInterval: .seconds(config.mqttKeepAliveInterval),
            connectTimeout: .seconds(30),
            userName: config.MQTT_USERNAME,
            password: config.MQTT_PASSWORD,
            tlsConfiguration: tlsConfiguration.map { .niossl($0) }
        )

        self.client = MQTTClient(
            host: config.MQTT_HOST,
            port: config.MQTT_PORT,
            identifier: clientIdUsed,
            eventLoopGroupProvider: .shared(MultiThreadedEventLoopGroup.singleton),
            logger: logger,
            configuration: clientConfiguration
        )
    }

    func start() async throws {
        try await client.connect()
    }

    func subscribe(to topics: [String]) async throws {
        let subscriptions = topics.map { topic in
            MQTTSubscribeInfo(topicFilter: topic, qos: .atLeastOnce)
        }
        let ack = try await client.subscribe(to: subscriptions)
        self.lastSubscribeAckDescription = "\(ack)"
        // Log per-topic return code for easier diagnostics
        /**
         if ack.returnCodes.count == topics.count {
             for (topic, rc) in zip(topics, ack.returnCodes) {
                 logger.info("MQTTClientService: suback for topic=\(topic) -> \(rc)")
             }
         } else {
             logger.info("MQTTClientService: subscribe returned ack=\(ack)")
         }
         */
    }

    /// 返回最近一次 subscribe 的 ack 描述（用于诊断）
    func subscribeAckDescription() -> String? {
        lastSubscribeAckDescription
    }

    /// 返回当前使用的 client id（用于诊断）
    func currentClientId() -> String {
        clientIdUsed
    }

    func publish(topic: String, payload: String) async throws {
        var buffer = ByteBufferAllocator().buffer(capacity: payload.utf8.count)
        buffer.writeString(payload)
        try await client.publish(to: topic, payload: buffer, qos: .atLeastOnce)
        logger.info("Published to \(topic): \(payload)")
    }

    /// 开始在后台监听 publish 消息，并把每个结果交给 handler
    func startListening(handler: @escaping (Result<MQTTPublishInfo, Error>) async -> Void) -> Task<Void, Never> {
        let task = Task {
            // Important: retain the AsyncSequence instance so it doesn't get deallocated
            // while the `for await` loop is running. Instantiating the sequence directly
            // inside `for await` can lead to the sequence object being released which
            // removes the underlying publish listener and results in no incoming events.
            let listener = client.createPublishListener()
            for await result in listener {
                switch result {
                case .success(_):
                    // logger.info("MQTTClientService: received publish for topic=\(msg.topicName)")
                    break
                case .failure(let err):
                    logger.warning("MQTTClientService: publish listener yielded error=\(err)")
                }
                await handler(result)
            }
        }
        self.listenerTask = task
        return task
    }

    /// 返回 listener 是否在运行（没有被取消）
    func isListening() -> Bool {
        guard let t = listenerTask else { return false }
        return !t.isCancelled
    }

    /// 取消当前 listener（如果有）并清理引用
    func stopListening() {
        listenerTask?.cancel()
        listenerTask = nil
        logger.info("MQTTClientService: listener cancelled")
    }
}
