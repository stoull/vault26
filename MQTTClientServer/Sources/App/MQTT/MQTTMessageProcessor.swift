import Foundation
import Fluent
import Logging

/// 负责处理接收到的 MQTT 消息的解析与持久化（与 DatabaseManager 解耦）
actor MQTTMessageProcessor {
    private let logger = Logger(label: "MQTTMessageProcessor")
    private let dbManager: DatabaseManager?

    init(dbManager: DatabaseManager?) {
        self.dbManager = dbManager
    }

    func process(topic: String, payloadString: String) async {
        // Diagnostic: log raw payload early to ensure we see incoming messages even if JSON parsing fails
        logger.info("RAW MQTT: topic=\(topic) payload=\(payloadString)")

        // 解析 JSON
        guard let data = payloadString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            logger.warning("Invalid JSON on topic \(topic)")
            return
        }

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
