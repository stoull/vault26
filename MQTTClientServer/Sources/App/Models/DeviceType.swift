//
//  DeviceType.swift
//  MQTTClientServer
//
//  Created by Hut on 2026/4/18.
//

import Foundation
import Fluent


/// 设备类型字典（MQTT 前缀、UI 元数据等），对应表 `device_type`
final class DeviceType: Model, @unchecked Sendable {
    static let schema = "device_type"

    @ID(custom: "id", generatedBy: .database)
    var id: Int?

    @Field(key: "name")
    var name: String

    // 写清楚，能表示机型的字符放前面，形式如：esp32_c3_supermini 放前面：esp32
    @Field(key: "code")
    var code: String

    @OptionalField(key: "description")
    var deviceDescription: String?

    @Field(key: "mqtt_prefix")
    var mqttPrefix: String

    @OptionalField(key: "icon")
    var icon: String?

    @OptionalField(key: "color")
    var color: String?

    @Field(key: "is_active")
    var isActive: Bool

    @OptionalField(key: "created_at")
    var createdAt: Date?

    @OptionalField(key: "updated_at")
    var updatedAt: Date?

    init() {}
}
