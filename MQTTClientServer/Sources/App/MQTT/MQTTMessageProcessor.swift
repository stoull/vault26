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
        logger.info("MQTTMessageProcessor: received RAW MQTT: topic=\(topic) payload=\(payloadString)")
        
        /**
        匹配 home/+/env/+/status 模式
        RAW MQTT: topic=home/livingroom/env/esp32c3_D777EC/state payload={"sensor_type":"dht22","sensor_id":4,"temperature":27.6,"humidity":71.7,"created_at":"2026-04-22T09:16:59+08:00"}
         */
        let pattern = "+/+/env/+/state" // 订阅所有上传的env类型数据
        if MQTTTopicPattern.matchesMQTTPattern(topic: topic, pattern: pattern),
           let locationRoot = MQTTTopicPattern.extractFromTopic(topic, pattern: pattern, wildcardIndex: 0),
           let locationCode = MQTTTopicPattern.extractFromTopic(topic, pattern: pattern, wildcardIndex: 1),
           let _ = MQTTTopicPattern.extractFromTopic(topic, pattern: pattern, wildcardIndex: 2) {
            await saveSensorEnvData(topic: topic, payload: payloadString, locationRootCode: locationRoot, locationCode: locationCode)
        }

        /**
        匹配 home/+/+/+/metrics，写入 edge_device_metric
         

        RAW MQTT: home/livingroom/env/esp32_D777EC/metrics payload={"unique_id":"ACA704D777EC","platform":"esp32c3","os_version":"v5.5.1-931-g9bb7aa84fe","cpu_frequency_mhz":160,"cpu_temperature":"","total_storage_bytes":4194304,"used_storage_bytes":0,"free_storage_bytes":1318001,"storage_usage_percent":68.57641,"total_memory_bytes":300472,"used_memory_bytes":104508,"free_memory_bytes":195964,"memory_usage_percent":34.78128,"uptime_seconds":67206,"reset_reason":0,"ip":"192.168.1.123","subnet":"255.255.255.0","gateway":"192.168.1.1","dns":"192.168.1.1","rssi":"-56","mac":"AC:A7:04:D7:77:EC","created_at":"2026-04-18T13:47:52+08:00"}
         */
        let deviceInfoPattern = "+/+/+/+/metrics"   // 订阅所有的设备信息
        if MQTTTopicPattern.matchesMQTTPattern(topic: topic, pattern: deviceInfoPattern),
           let locationRoot = MQTTTopicPattern.extractFromTopic(topic, pattern: deviceInfoPattern, wildcardIndex: 0),
           let locationCode = MQTTTopicPattern.extractFromTopic(topic, pattern: deviceInfoPattern, wildcardIndex: 1),
           let _ = MQTTTopicPattern.extractFromTopic(topic, pattern: deviceInfoPattern, wildcardIndex: 2),
           let topicDeviceSegment = MQTTTopicPattern.extractFromTopic(topic, pattern: deviceInfoPattern, wildcardIndex: 3) {
            await saveEdgeDeviceMetricData(
                topic: topic,
                payload: payloadString,
                topicDeviceSegment: topicDeviceSegment,
                locationRootCode: locationRoot,
                locationCode: locationCode
            )
        }
    }
    
    /// 将 `+/+/env/+/state` 消息的 JSON 写入 `environment_readings` 表
    private func saveSensorEnvData(topic: String, payload: String, locationRootCode: String, locationCode: String) async {
        // RAW MQTT: topic=home/livingroom/env/1/state payload={"temp":27.1,"humi":65.4,"type":"sth30","created_at":"2026-04-18T13:42:52+08:00"}

        guard let data = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            logger.warning("Invalid JSON on topic \(topic)")
            return
        }

        let sensorIdInt = jsonIntOptional(json, keys: ["sensor_id", "sensorId"])
        let temperature = jsonDouble(json, keys: ["temperature", "temp"])
        let humidity = jsonDouble(json, keys: ["humidity", "humi"])
        let illuminance = jsonDouble(json, keys: ["illuminance", "lux", "light"])
        let pm25 = jsonDouble(json, keys: ["pm25", "pm2_5", "pm_25"])
        let co2 = jsonDouble(json, keys: ["co2"])
        let hcho = jsonDouble(json, keys: ["hcho", "formaldehyde"])
        let tvoc = jsonDouble(json, keys: ["tvoc"])
        let pressure = jsonDouble(json, keys: ["pressure", "pressure_pa"])
        let smokeGas = jsonDouble(json, keys: ["smoke_gas", "smokeGas", "smoke", "gas"])
        let createdAtISO = jsonStringNonEmpty(json, keys: ["created_at", "createdAt"])

        guard let dbManager = self.dbManager else {
            logger.warning("No DatabaseManager available: skipping save for topic=\(topic)")
            return
        }
        let db = dbManager.db()

        // 匹配 `location.code`（如 topic 中的 livingroom），写入外键 `location_id`
        let locationRootRow: Location?
        let locationRow: Location?
        do {
            locationRootRow = try await Location.query(on: db).filter(\.$code == locationRootCode).first()
            locationRow = try await Location.query(on: db).filter(\.$code == locationCode).first()
        } catch {
            logger.error("Location lookup failed for locationCode=\(locationCode): \(error)")
            return
        }
        guard let locationRow, let locationRootRow,
              let locationId = locationRow.id, let locationRootId = locationRootRow.id else {
            logger.warning("Location not found for locationCode=\(locationCode)")
            return
        }

        //  在读取一下 sensor_type 表，获取 sensor_type_id
        let sensorType = jsonStringNonEmpty(json, keys: ["sensor_type", "type"]) ?? ""
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

        let record = EnvironmentReadings(
            locationRootId: locationRootId,
            locationId: locationId,
            sensorId: sensorIdInt,
            sensorType: sensorTypeId,
            temperature: temperature,
            humidity: humidity,
            illuminance: illuminance,
            pm25: pm25,
            co2: co2,
            hcho: hcho,
            tvoc: tvoc,
            pressure: pressure,
            smokeGas: smokeGas,
            createdAtISO: createdAtISO
        )

        do {
            try await dbManager.withRetry(maxAttempts: 3, delay: .seconds(2)) {
                try await record.save(on: db)
            }
            logger.info("Saved EnvironmentReadings topic=\(topic) sensor_type=\(sensorTypeRow.name) sensor_id=\(sensorIdInt.map { String($0) } ?? "nil")")
        } catch {
            logger.error("Save failed after retries: \(error)")
        }
    }

    /// 将 `+/+/+/+/metrics` 的 JSON 写入 `edge_device_metric`。`device_id`：主题第四段为整数时直接用；否则用 JSON 的 `unique_id` 查 `edge_device`。
    private func saveEdgeDeviceMetricData(
        topic: String,
        payload: String,
        topicDeviceSegment: String,
        locationRootCode: String?,
        locationCode: String?
    ) async {
        guard let data = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            logger.warning("device_info invalid JSON on topic \(topic)")
            return
        }

        guard let createdAtISO = jsonStringNonEmpty(json, keys: ["created_at", "createdAt"]),
              jsonStringNonEmpty(json, keys: ["unique_id", "uniqueId"]) != nil
        else {
            logger.warning("device_info missing created_at or unique_id topic=\(topic) payload=\(payload)")
            return
        }

        guard let dbManager = self.dbManager else {
            logger.warning("No DatabaseManager available: skipping save for topic=\(topic)")
            return
        }
        let db = dbManager.db()

        let deviceId: Int?
        if let fromTopic = Int(topicDeviceSegment) {
            deviceId = fromTopic
        } else if let uid = jsonStringNonEmpty(json, keys: ["unique_id", "uniqueId"]) {
            do {
                let dev = try await EdgeDevice.query(on: db).filter(\.$uniqueId == uid).first()
                deviceId = dev?.id
            } catch {
                logger.error("EdgeDevice lookup failed for unique_id=\(uid): \(error)")
                return
            }
        } else {
            deviceId = nil
        }

        guard let deviceId else {
            logger.warning(
                "Could not resolve device_id for metrics topic=\(topic) segment=\(topicDeviceSegment) (use numeric topic segment or unique_id in JSON)"
            )
            return
        }

        var locationRootId: Int? = nil
        var locationId: Int? = nil
        if let locationRootCode = locationRootCode, let locationCode = locationCode {
            let locationRootRow: Location?
            let locationRow: Location?
            do {
                locationRootRow = try await Location.query(on: db).filter(\.$code == locationRootCode).first()
                locationRow = try await Location.query(on: db).filter(\.$code == locationCode).first()
            } catch {
                logger.error("Location lookup failed for locationCode=\(locationCode): \(error)")
                return
            }
            if let locationRootRow, let loRootId = locationRootRow.id {
                locationRootId = loRootId
            }
            if let locationRow, let loId = locationRow.id {
                locationId = loId
            }
        }

        let record = EdgeDeviceMetric()
        record.$location_root.id = locationRootId
        record.$location.id = locationId
        record.$device.id = deviceId
        record.createdAtISO = createdAtISO
        record.timestamp = Date()
        record.platform = jsonStringNonEmpty(json, keys: ["platform"])
        record.osVersion = jsonStringNonEmpty(json, keys: ["os_version", "osVersion"])
        record.cpuFrequencyMhz = jsonIntOptional(json, keys: ["cpu_frequency_mhz", "cpuFrequencyMhz"])
        record.cpuTemperature = jsonDouble(json, keys: ["cpu_temperature", "cpuTemperature"])
        record.totalStorageBytes = jsonInt64Optional(json, keys: ["total_storage_bytes", "totalStorageBytes"])
        record.usedStorageBytes = jsonInt64Optional(json, keys: ["used_storage_bytes", "usedStorageBytes"])
        record.freeStorageBytes = jsonInt64Optional(json, keys: ["free_storage_bytes", "freeStorageBytes"])
        record.storageUsagePercent = jsonDouble(json, keys: ["storage_usage_percent", "storageUsagePercent"])
        record.totalMemoryBytes = jsonInt64Optional(json, keys: ["total_memory_bytes", "totalMemoryBytes"])
        record.usedMemoryBytes = jsonInt64Optional(json, keys: ["used_memory_bytes", "usedMemoryBytes"])
        record.freeMemoryBytes = jsonInt64Optional(json, keys: ["free_memory_bytes", "freeMemoryBytes"])
        record.memoryUsagePercent = jsonDouble(json, keys: ["memory_usage_percent", "memoryUsagePercent"])
        record.uptimeSeconds = jsonInt64Optional(json, keys: ["uptime_seconds", "uptimeSeconds"])
        record.resetReason = jsonIntDefault(json, keys: ["reset_reason", "resetReason"])
        record.batteryLevelPercent = jsonDouble(json, keys: ["battery_level_percent", "batteryLevelPercent"])
        record.ip = jsonStringNonEmpty(json, keys: ["ip"])
        record.mac = jsonStringNonEmpty(json, keys: ["mac"])
        record.subnet = jsonStringNonEmpty(json, keys: ["subnet"])
        record.dns = jsonStringNonEmpty(json, keys: ["dns"])
        record.gateway = jsonStringNonEmpty(json, keys: ["gateway"])
        record.rssi = jsonIntOptional(json, keys: ["rssi"])
        record.extraData = jsonExtraDataString(json)

        do {
            try await dbManager.withRetry(maxAttempts: 3, delay: .seconds(2)) {
                try await record.save(on: db)
            }
            logger.info("Saved EdgeDeviceMetric topic=\(topic) device_id=\(deviceId)")
        } catch {
            logger.error("EdgeDeviceMetric save failed after retries: \(error)")
        }
    }

    private func jsonExtraDataString(_ json: [String: Any]) -> String? {
        let extra: [String: Any] = [:]
//        if let uid = jsonStringNonEmpty(json, keys: ["unique_id", "uniqueId"]) {
//            extra["unique_id"] = uid
//        }
        guard !extra.isEmpty,
              let d = try? JSONSerialization.data(withJSONObject: extra),
              let s = String(data: d, encoding: .utf8)
        else { return nil }
        return s
    }

    private func jsonStringNonEmpty(_ json: [String: Any], keys: [String]) -> String? {
        for key in keys {
            guard let s = json[key] as? String else { continue }
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { return t }
        }
        return nil
    }

    /// 与旧 SwiftyJSON `intValue` 类似：缺省或无法解析时为 0
    private func jsonIntDefault(_ json: [String: Any], keys: [String]) -> Int {
        for key in keys {
            if let i = json[key] as? Int { return i }
            if let d = json[key] as? Double { return Int(d) }
            if let n = json[key] as? NSNumber { return n.intValue }
            if let s = json[key] as? String {
                let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { continue }
                if let v = Int(t) { return v }
                continue
            }
        }
        return 0
    }

    private func jsonIntOptional(_ json: [String: Any], keys: [String]) -> Int? {
        for key in keys {
            if let i = json[key] as? Int { return i }
            if let d = json[key] as? Double { return Int(d) }
            if let n = json[key] as? NSNumber { return n.intValue }
            if let s = json[key] as? String {
                let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { continue }
                if let v = Int(t) { return v }
            }
        }
        return nil
    }

    private func jsonInt64Optional(_ json: [String: Any], keys: [String]) -> Int64? {
        for key in keys {
            if let i = json[key] as? Int { return Int64(i) }
            if let i = json[key] as? Int64 { return i }
            if let d = json[key] as? Double { return Int64(d) }
            if let n = json[key] as? NSNumber { return n.int64Value }
            if let s = json[key] as? String {
                let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { continue }
                if let v = Int64(t) { return v }
            }
        }
        return nil
    }

    private func jsonDouble(_ json: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            if let d = json[key] as? Double { return d }
            if let i = json[key] as? Int { return Double(i) }
            if let n = json[key] as? NSNumber { return n.doubleValue }
            if let s = json[key] as? String {
                let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                if let v = Double(trimmed) { return v }
            }
        }
        return nil
    }

}
