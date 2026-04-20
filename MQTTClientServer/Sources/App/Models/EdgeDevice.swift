//
//  EdgeDevice.swift
//  MQTTClientServer
//
//  Fluent 映射：已存在的 MariaDB/MySQL 表 edge_device
//

import Foundation
import Fluent

/// 边缘设备（合并原 `device` 逻辑设备与 `edge_device` 物理/逻辑登记），表 `edge_device`
final class EdgeDevice: Model, @unchecked Sendable {
    static let schema = "edge_device"

    @ID(custom: "id", generatedBy: .database)
    var id: Int?

    @Field(key: "unique_id")
    var uniqueId: String

    /**
     逻辑：取设备类型前缀 + 物理ID的后4位 (类似 MAC 地址缩短版)
     结果示例：
     ESP32 C3 -> "ESP_E410F8"
     Raspberry -> "RAS_454311"
     */
    @Field(key: "code")
    var code: String

    /// 外键 → `device_type.id`（列名 `device_type`）
    @Parent(key: "device_type")
    var deviceType: DeviceType

    @OptionalField(key: "device_name")
    var deviceName: String?

    @Field(key: "location_id")
    var locationId: Int

    /// 列名为 SQL 保留字 `description`，Swift 侧避免与 `CustomStringConvertible.description` 冲突
    @OptionalField(key: "description")
    var deviceDescription: String?

    @OptionalField(key: "group_name")
    var groupName: String?

    /// MQTT 主题前缀（如 `home/livingroom/env/001`）
    @Field(key: "mqtt_topic")
    var mqttTopic: String

    /// 如 `offline` / `online`
    @Field(key: "status")
    var status: String

    @OptionalField(key: "firmware_version")
    var firmwareVersion: String?

    @OptionalField(key: "hardware_version")
    var hardwareVersion: String?

    @Field(key: "created_at")
    var createdAt: Date

    @Field(key: "last_seen")
    var lastSeen: Date

    @OptionalField(key: "updated_at")
    var updatedAt: Date?

    @OptionalField(key: "ip_address")
    var ipAddress: String?

    @OptionalField(key: "mac_address")
    var macAddress: String?

    /// 1=活跃, 0=停用（库列为 NOT NULL）
    @Field(key: "is_active")
    var isActive: Int

    @Field(key: "sort_order")
    var sortOrder: Int

    @Children(for: \.$device)
    var metric: [EdgeDeviceMetric]

    init() {}
}
