//
//  SystemDevice.swift
//  MQTTClientServer
//
//  Fluent 映射：已存在的 MariaDB/MySQL 表 system_devices
//

import Foundation
import Fluent

/// 设备基础信息，对应 Python `SystemDevice` / 表 `system_devices`
final class SystemDevice: Model, @unchecked Sendable {
    static let schema = "system_devices"

    @ID(custom: "id", generatedBy: .database)
    var id: Int?

    @Field(key: "unique_id")
    var uniqueId: String

    @Field(key: "device_type")
    var deviceType: Int

    @OptionalField(key: "device_name")
    var deviceName: String?

    /// 列名为 SQL 保留字 `description`，Swift 侧避免与 `CustomStringConvertible.description` 冲突
    @OptionalField(key: "description")
    var deviceDescription: String?

    @OptionalField(key: "location")
    var location: String?

    @OptionalField(key: "group_name")
    var groupName: String?

    @Field(key: "created_at")
    var createdAt: Date

    @Field(key: "last_seen")
    var lastSeen: Date

    /// 1=活跃, 0=停用（库列为 NOT NULL）
    @Field(key: "is_active")
    var isActive: Int

    @Children(for: \.$device)
    var snapshots: [SystemDeviceSnapshot]

    init() {}
}
