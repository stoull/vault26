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
        匹配 home/+/env/+/status 模式
        RAW MQTT: topic=home/livingroom/env/1/state payload={"temp":27.1,"humi":65.4,"type":"sth30","created_at":"2026-04-18T13:42:52+08:00"}
         */
        let pattern = "home/+/env/+/state" // 原为：sensor/env/+/+/data
        if MQTTTopicPattern.matchesMQTTPattern(topic: topic, pattern: pattern),
              let locationCode = MQTTTopicPattern.extractFromTopic(topic, pattern: pattern, wildcardIndex: 0),
           let sensorId = MQTTTopicPattern.extractFromTopic(topic, pattern: pattern, wildcardIndex: 1) {
            await saveSensorEnvData(topic: topic, payload: payloadString, locationCode: locationCode, sensorId: sensorId)
        }

        /**
        匹配 home/+/+/+/metrics，写入 edge_device_metric
        RAW MQTT: home/livingroom/env/4/metrics payload={"unique_id":"ACA704D777EC","platform":"esp32c3","os_version":"v5.5.1-931-g9bb7aa84fe","cpu_frequency_mhz":160,"cpu_temperature":"","total_storage_bytes":4194304,"used_storage_bytes":0,"free_storage_bytes":1318001,"storage_usage_percent":68.57641,"total_memory_bytes":300472,"used_memory_bytes":104508,"free_memory_bytes":195964,"memory_usage_percent":34.78128,"uptime_seconds":67206,"reset_reason":0,"ip":"192.168.1.123","subnet":"255.255.255.0","gateway":"192.168.1.1","dns":"192.168.1.1","rssi":"-56","mac":"AC:A7:04:D7:77:EC","created_at":"2026-04-18T13:47:52+08:00"}
         */
        let deviceInfoPattern = "home/+/+/+/metrics"    // 原为：device/system/+/device_info
        if MQTTTopicPattern.matchesMQTTPattern(topic: topic, pattern: deviceInfoPattern),
           let locationCode = MQTTTopicPattern.extractFromTopic(topic, pattern: deviceInfoPattern, wildcardIndex: 0),
           let typeCode = MQTTTopicPattern.extractFromTopic(topic, pattern: deviceInfoPattern, wildcardIndex: 1),
           let deviceIdStr = MQTTTopicPattern.extractFromTopic(topic, pattern: deviceInfoPattern, wildcardIndex: 2),
           let deviceId = Int(deviceIdStr) {
            await saveEdgeDeviceMetricData(topic: topic, payload: payloadString, deviceId: deviceId)
        }
    }
    
    /// 将 `home/+/env/+/status` 消息的 JSON 写入 `sensor_data_temp_humi` 表
    private func saveSensorEnvData(topic: String, payload: String, locationCode: String, sensorId: String) async {
        guard let sensorIdInt = Int(sensorId)
        else {
            logger.warning(
                "Topic \(topic): sensor_id must be integers, got sensorId=\(sensorId)"
            )
            return
        }
        
        // RAW MQTT: topic=home/livingroom/env/1/state payload={"temp":27.1,"humi":65.4,"type":"sth30","created_at":"2026-04-18T13:42:52+08:00"}

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

        guard let dbManager = self.dbManager else {
            logger.warning("No DatabaseManager available: skipping save for topic=\(topic)")
            return
        }
        let db = dbManager.db()

        // 匹配 `location.code`（如 topic 中的 livingroom），写入外键 `location_id`
        let locationRow: Location?
        do {
            locationRow = try await Location.query(on: db).filter(\.$code == locationCode).first()
        } catch {
            logger.error("Location lookup failed for locationCode=\(locationCode): \(error)")
            return
        }
        guard let locationRow, let locationId = locationRow.id else {
            logger.warning("Location not found for locationCode=\(locationCode)")
            return
        }

        //  在读取一下 sensor_type 表，获取 sensor_type_id
        var sensorType = jsonStringNonEmpty(json, key: "type") ?? ""
        let sensorTypeRow: SensorType?
        do {
            sensorTypeRow = try await SensorType.query(on: db).filter(\.$code == sensorType).first()
        } catch {
            logger.error("SensorType lookup failed for sensorType=\(sensorType): \(error)")
            return
        }
        guard let sensorTypeRow, let sensorTypeId = sensorTypeRow.id else {
            logger.warning("SensorType not found for sensorType=\(sensorType)")
            return
        }

        let record = SensorDataTempHumi(
            locationId: locationId,
            sensorId: sensorIdInt,
            sensorType: sensorTypeId,
            temperature: temperature,
            humidity: humidity,
            created_at: createdAtISO
        )

        do {
            try await dbManager.withRetry(maxAttempts: 3, delay: .seconds(2)) {
                try await record.save(on: db)
            }
            logger.info("Saved SensorDataTempHumi topic=\(topic) sensor_type=\(sensorTypeRow.name) sensor_id=\(sensorIdInt)")
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
    
}
