//
//  EdgeDeviceMetric.swift
//  MQTTClientServer
//
//  Fluent 映射：已存在的 MariaDB/MySQL 表 edge_device_metric
//

import Foundation
import Fluent

/// 设备状态快照（时序），对应 Python `EdgeDeviceMetric` / 表 `edge_device_metric`
final class EdgeDeviceMetric: Model, @unchecked Sendable {
    static let schema = "edge_device_metric"
    
    @ID(custom: "id", generatedBy: .database)
    var id: Int?

    @Parent(key: "device_id")
    var device: EdgeDevice

    @OptionalField(key: "created_at_iso")
    var createdAtISO: String?

    /// 记录时间（列名为 `timestamp`，与 SQLAlchemy 一致）
    @Field(key: "timestamp")
    var timestamp: Date

    @OptionalField(key: "platform")
    var platform: String?

    @OptionalField(key: "os_version")
    var osVersion: String?

    @OptionalField(key: "cpu_frequency_mhz")
    var cpuFrequencyMhz: Int?

    @OptionalField(key: "cpu_temperature")
    var cpuTemperature: Double?

    @OptionalField(key: "total_storage_bytes")
    var totalStorageBytes: Int64?

    @OptionalField(key: "used_storage_bytes")
    var usedStorageBytes: Int64?

    @OptionalField(key: "free_storage_bytes")
    var freeStorageBytes: Int64?

    @OptionalField(key: "storage_usage_percent")
    var storageUsagePercent: Double?

    @OptionalField(key: "total_memory_bytes")
    var totalMemoryBytes: Int64?

    @OptionalField(key: "used_memory_bytes")
    var usedMemoryBytes: Int64?

    @OptionalField(key: "free_memory_bytes")
    var freeMemoryBytes: Int64?

    @OptionalField(key: "memory_usage_percent")
    var memoryUsagePercent: Double?

    @OptionalField(key: "uptime_seconds")
    var uptimeSeconds: Int64?

    @Field(key: "reset_reason")
    var resetReason: Int

    @OptionalField(key: "battery_level_percent")
    var batteryLevelPercent: Double?

    @OptionalField(key: "ip")
    var ip: String?

    @OptionalField(key: "mac")
    var mac: String?

    @OptionalField(key: "subnet")
    var subnet: String?

    @OptionalField(key: "dns")
    var dns: String?

    @OptionalField(key: "gateway")
    var gateway: String?

    @OptionalField(key: "rssi")
    var rssi: Int?

    /// MySQL `JSON` 列：以 UTF-8 字符串形式读写，需要结构化数据时可自行 `JSONSerialization` / `Codable` 解析
    @OptionalField(key: "extra_data")
    var extraData: String?

    init() {}
}
