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


        
        // 匹配 sensor/env/+/+/data 模式
        if let (deviceType, sensorId) = matchSensorEnvTopic(topic) {
            await saveSensorEnvData(
                topic: topic,
                payload: payloadString,
                deviceType: deviceType,
                sensorId: sensorId
            )
        }
    }
    
    /// 将 `sensor/env/+/+/data` 消息的 JSON 写入 `sensor_data_temp_humi` 表
    private func saveSensorEnvData(topic: String, payload: String, deviceType: String, sensorId: String) async {
        guard let sensorIdInt = Int(sensorId)
        else {
            logger.warning(
                "Topic \(topic): sensor_id must be integers, got sensorId=\(sensorId)"
            )
            return
        }
        
        var deviceTypeInt = 0
        switch deviceType.lowercased() {
            /**
             SHT30 / SHT31 / SHT35（瑞士 Sensirion）
             SHT40 / SHT41 / SHT45（新一代高精度）
             SHTC3（低功耗小体积）
             AM2302 (DHT22) 单总线，性价比高
             DHT11 入门级，精度一般
             AHT10 / AHT20 / AHT25（国产高性价比）
             BME280 / BME680（博世，温湿度 + 气压，BME680 还带气体）
             HTU21D / HTU31D（Measurement Specialties）
             */
            case "dht11": deviceTypeInt = 1
            case "dht20": deviceTypeInt = 2
            case "dht22","am2302": deviceTypeInt = 3
            case "sht30": deviceTypeInt = 4
            case "sht31": deviceTypeInt = 5
            case "sht35": deviceTypeInt = 6
            
            case "aht10": deviceTypeInt = 7
            case "aht20": deviceTypeInt = 8
            case "aht25": deviceTypeInt = 9
        
            
            case "sht40": deviceTypeInt = 10
            case "sht41": deviceTypeInt = 11
            case "sht45": deviceTypeInt = 12
            
            case "bme280": deviceTypeInt = 13
            case "bme680": deviceTypeInt = 14
            
            case "htu21d": deviceTypeInt = 15
            case "htu31d": deviceTypeInt = 16
            default:
                logger.warning(
                    "Topic \(topic): unrecognized device_type=\(deviceType), defaulting to 0"
                )
        }

        guard let data = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            logger.warning("Invalid JSON on topic \(topic)")
            return
        }

        let temperature = jsonDouble(json, key: "temperature")
        let humidity = jsonDouble(json, key: "humidity")
        let createdAtISO =
            (json["created_at"] as? String)
            ?? (json["createdAt"] as? String)
        
        let record = SensorDataTempHumi(
            sensorType: deviceTypeInt,
            sensorId: sensorIdInt,
            temperature: temperature,
            humidity: humidity,
            created_at: createdAtISO
        )

        do {
            if let dbManager = self.dbManager {
                try await dbManager.withRetry(maxAttempts: 3, delay: .seconds(2)) {
                    try await record.save(on: dbManager.db())
                }
                logger.info("Saved SensorDataTempHumi topic=\(topic) sensor_type=\(deviceTypeInt) sensor_id=\(sensorIdInt)")
            } else {
                logger.warning("No DatabaseManager available: skipping save for topic=\(topic)")
            }
        } catch {
            logger.error("Save failed after retries: \(error)")
        }
    }

    private func jsonDouble(_ json: [String: Any], key: String) -> Double? {
        if let d = json[key] as? Double { return d }
        if let i = json[key] as? Int { return Double(i) }
        if let n = json[key] as? NSNumber { return n.doubleValue }
        if let s = json[key] as? String {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return Double(trimmed)
        }
        return nil
    }
    
    /// 匹配 `sensor/env/+/+/data`，成功时返回 (device_type, sensor_id)
    private func matchSensorEnvTopic(_ topic: String) -> (deviceType: String, sensorId: String)? {
        let pattern = "sensor/env/+/+/data"
        guard matchesMQTTPattern(topic: topic, pattern: pattern),
              let deviceType = extractFromTopic(topic, pattern: pattern, wildcardIndex: 0),
              let sensorId = extractFromTopic(topic, pattern: pattern, wildcardIndex: 1)
        else { return nil }
        return (deviceType, sensorId)
    }
    
    // MARK: - MQTT Topic Matching Utilities
    
    /// 匹配 MQTT 主题模式，支持单层通配符 (+) 和多层通配符 (#)
    /// - Parameters:
    ///   - topic: 实际收到的主题，如 "sensor/dht22/1/data"
    ///   - pattern: 订阅模式，如 "sensor/dht22/+/data"
    /// - Returns: 是否匹配
    private func matchesMQTTPattern(topic: String, pattern: String) -> Bool {
        let topicLevels = topic.split(separator: "/").map(String.init)
        let patternLevels = pattern.split(separator: "/").map(String.init)
        
        // 处理多层通配符 #（只能在最后）
        if patternLevels.last == "#" {
            // 模式必须短于或等于主题
            if patternLevels.count - 1 > topicLevels.count {
                return false
            }
            // 检查 # 之前的所有层级
            for i in 0..<(patternLevels.count - 1) {
                if patternLevels[i] != "+" && patternLevels[i] != topicLevels[i] {
                    return false
                }
            }
            return true
        }
        
        // 不使用 # 时，层级数必须相同
        guard topicLevels.count == patternLevels.count else {
            return false
        }
        
        // 逐层匹配
        for (topicLevel, patternLevel) in zip(topicLevels, patternLevels) {
            if patternLevel != "+" && patternLevel != topicLevel {
                return false
            }
        }
        
        return true
    }
    
    /// 从主题中提取特定位置的值
    /// 例如: extractFromTopic("sensor/dht22/1/data", pattern: "sensor/dht22/+/data", wildcardIndex: 0) -> "1"
    private func extractFromTopic(_ topic: String, pattern: String, wildcardIndex: Int) -> String? {
        let topicLevels = topic.split(separator: "/").map(String.init)
        let patternLevels = pattern.split(separator: "/").map(String.init)
        
        guard topicLevels.count == patternLevels.count else {
            return nil
        }
        
        var wildcardCount = 0
        for (index, patternLevel) in patternLevels.enumerated() {
            if patternLevel == "+" {
                if wildcardCount == wildcardIndex {
                    return topicLevels[index]
                }
                wildcardCount += 1
            }
        }
        
        return nil
    }
}
