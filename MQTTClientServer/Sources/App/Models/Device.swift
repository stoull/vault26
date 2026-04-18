//
//  Device.swift
//  MQTTClientServer
//
//  Created by Hut on 2026/4/18.
//

import Foundation
import Fluent

/// 挂在某 `location` 下的逻辑设备，对应表 `device`
final class Device: Model, @unchecked Sendable {
    static let schema = "device"

    @ID(custom: "id", generatedBy: .database)
    var id: Int?

    @Field(key: "location_id")
    var locationId: Int

    @Field(key: "name")
    var name: String

    @Field(key: "code")
    var code: String

    /// 列名为 `type`，外键 → `device_type.id`
    @Parent(key: "type")
    var deviceType: DeviceType

    @Field(key: "mqtt_topic")
    var mqttTopic: String

    /// 如 `offline` / `online`
    @Field(key: "status")
    var status: String

    @OptionalField(key: "firmware_version")
    var firmwareVersion: String?

    @OptionalField(key: "hardware_version")
    var hardwareVersion: String?

    @OptionalField(key: "last_seen")
    var lastSeen: Date?

    @OptionalField(key: "ip_address")
    var ipAddress: String?

    @OptionalField(key: "mac_address")
    var macAddress: String?

    @Field(key: "is_active")
    var isActive: Bool

    @Field(key: "sort_order")
    var sortOrder: Int

    @OptionalField(key: "created_at")
    var createdAt: Date?

    @OptionalField(key: "updated_at")
    var updatedAt: Date?

    init() {}
}
