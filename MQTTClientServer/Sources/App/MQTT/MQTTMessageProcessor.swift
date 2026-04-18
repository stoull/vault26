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
        
        /**
         RAW MQTT: topic=home/livingroom/env/1/state payload={"temp":27.1,"humi":65.4,"type":"sth30","created_at":"2026-04-18T13:42:52+08:00"}
         */
        // 匹配 home/+/env/+/status 模式
        let pattern = "home/+/env/+/status" // 原为：sensor/env/+/+/data
        if matchesMQTTPattern(topic: topic, pattern: pattern),
              let deviceType = extractFromTopic(topic, pattern: pattern, wildcardIndex: 0),
           let sensorId = extractFromTopic(topic, pattern: pattern, wildcardIndex: 1) {
            await saveSensorEnvData(topic: topic, payload: payloadString, deviceType: deviceType, sensorId: sensorId)
        }

        /**
         RAW MQTT: home/livingroom/env/1/metrics payload={"unique_id":"ACA704D777EC","platform":"esp32c3","os_version":"v5.5.1-931-g9bb7aa84fe","cpu_frequency_mhz":160,"cpu_temperature":"","total_storage_bytes":4194304,"used_storage_bytes":0,"free_storage_bytes":1318001,"storage_usage_percent":68.57641,"total_memory_bytes":300472,"used_memory_bytes":104508,"free_memory_bytes":195964,"memory_usage_percent":34.78128,"uptime_seconds":67206,"reset_reason":0,"ip":"192.168.1.123","subnet":"255.255.255.0","gateway":"192.168.1.1","dns":"192.168.1.1","rssi":"-56","mac":"AC:A7:04:D7:77:EC","created_at":"2026-04-18T13:47:52+08:00"}
         */
        // 匹配 home/+/+/+/metrics，写入 edge_device_metric
        let deviceInfoPattern = "home/+/+/+/metrics"    // 原为：device/system/+/device_info
        if matchesMQTTPattern(topic: topic, pattern: deviceInfoPattern),
           let deviceIdStr = extractFromTopic(topic, pattern: deviceInfoPattern, wildcardIndex: 0),
           let deviceId = Int(deviceIdStr) {
            await saveEdgeDeviceMetricData(topic: topic, payload: payloadString, deviceId: deviceId)
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

    /// 将 `device/system/+/device_info` 的 JSON 写入 `edge_device_metric`（与旧 MySQL 插入逻辑对齐；`os_version` 使用 JSON 的 `os_version`，`unique_id` 写入 `extra_data`）
    private func saveEdgeDeviceMetricData(topic: String, payload: String, deviceId: Int) async {
        guard let data = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            logger.warning("device_info invalid JSON on topic \(topic)")
            return
        }

        guard let createdAtISO = jsonStringNonEmpty(json, key: "created_at"),
              jsonStringNonEmpty(json, key: "unique_id") != nil
        else {
            logger.warning("device_info missing created_at or unique_id topic=\(topic) payload=\(payload)")
            return
        }

        let record = EdgeDeviceMetric()
        record.$device.id = deviceId
        record.createdAtISO = createdAtISO
        record.timestamp = Date()
        record.platform = jsonStringNonEmpty(json, key: "platform")
        record.osVersion = jsonStringNonEmpty(json, key: "os_version")
        record.cpuFrequencyMhz = jsonIntOptional(json, key: "cpu_frequency_mhz")
        record.cpuTemperature = jsonDouble(json, key: "cpu_temperature")
        record.totalStorageBytes = jsonInt64Optional(json, key: "total_storage_bytes")
        record.usedStorageBytes = jsonInt64Optional(json, key: "used_storage_bytes")
        record.freeStorageBytes = jsonInt64Optional(json, key: "free_storage_bytes")
        record.storageUsagePercent = jsonDouble(json, key: "storage_usage_percent")
        record.totalMemoryBytes = jsonInt64Optional(json, key: "total_memory_bytes")
        record.usedMemoryBytes = jsonInt64Optional(json, key: "used_memory_bytes")
        record.freeMemoryBytes = jsonInt64Optional(json, key: "free_memory_bytes")
        record.memoryUsagePercent = jsonDouble(json, key: "memory_usage_percent")
        record.uptimeSeconds = jsonInt64Optional(json, key: "uptime_seconds")
        record.resetReason = jsonIntDefault(json, key: "reset_reason")
        record.batteryLevelPercent = jsonDouble(json, key: "battery_level_percent")
        record.ip = jsonStringNonEmpty(json, key: "ip")
        record.mac = jsonStringNonEmpty(json, key: "mac")
        record.subnet = jsonStringNonEmpty(json, key: "subnet")
        record.dns = jsonStringNonEmpty(json, key: "dns")
        record.gateway = jsonStringNonEmpty(json, key: "gateway")
        record.rssi = jsonIntOptional(json, key: "rssi")
        record.extraData = jsonExtraDataString(json)

        do {
            if let dbManager = self.dbManager {
                try await dbManager.withRetry(maxAttempts: 3, delay: .seconds(2)) {
                    try await record.save(on: dbManager.db())
                }
                logger.info("Saved EdgeDeviceMetric topic=\(topic) device_id=\(deviceId)")
            } else {
                logger.warning("No DatabaseManager available: skipping device_info for topic=\(topic)")
            }
        } catch {
            logger.error("EdgeDeviceMetric save failed after retries: \(error)")
        }
    }

    private func jsonExtraDataString(_ json: [String: Any]) -> String? {
        let extra: [String: Any] = [:]
//        if let uid = jsonStringNonEmpty(json, key: "unique_id") {
//            extra["unique_id"] = uid
//        }
        guard !extra.isEmpty,
              let d = try? JSONSerialization.data(withJSONObject: extra),
              let s = String(data: d, encoding: .utf8)
        else { return nil }
        return s
    }

    private func jsonStringNonEmpty(_ json: [String: Any], key: String) -> String? {
        guard let s = json[key] as? String else { return nil }
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    /// 与旧 SwiftyJSON `intValue` 类似：缺省或无法解析时为 0
    private func jsonIntDefault(_ json: [String: Any], key: String) -> Int {
        if let i = json[key] as? Int { return i }
        if let d = json[key] as? Double { return Int(d) }
        if let n = json[key] as? NSNumber { return n.intValue }
        if let s = json[key] as? String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return Int(t) ?? 0
        }
        return 0
    }

    private func jsonIntOptional(_ json: [String: Any], key: String) -> Int? {
        if let i = json[key] as? Int { return i }
        if let d = json[key] as? Double { return Int(d) }
        if let n = json[key] as? NSNumber { return n.intValue }
        if let s = json[key] as? String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return nil }
            return Int(t)
        }
        return nil
    }

    private func jsonInt64Optional(_ json: [String: Any], key: String) -> Int64? {
        if let i = json[key] as? Int { return Int64(i) }
        if let i = json[key] as? Int64 { return i }
        if let d = json[key] as? Double { return Int64(d) }
        if let n = json[key] as? NSNumber { return n.int64Value }
        if let s = json[key] as? String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return nil }
            return Int64(t)
        }
        return nil
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
