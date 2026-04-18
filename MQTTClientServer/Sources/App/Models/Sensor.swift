//
//  Sensor.swift
//  MQTTClientServer
//
//  Created by Hut on 2026/4/18.
//

import Foundation
import Fluent

/// 隶属于 `device` 的传感点/通道，对应表 `sensor`
final class Sensor: Model, @unchecked Sendable {
    static let schema = "sensor"

    @ID(custom: "id", generatedBy: .database)
    var id: Int?

    @Field(key: "device_id")
    var deviceId: Int

    @Field(key: "name")
    var name: String

    @Field(key: "code")
    var code: String

    @Field(key: "type")
    var sensorType: String

    @OptionalField(key: "unit")
    var unit: String?

    @OptionalField(key: "mqtt_field")
    var mqttField: String?

    @Field(key: "precision_val")
    var precisionVal: Int

    @OptionalField(key: "min_value")
    var minValue: Double?

    @OptionalField(key: "max_value")
    var maxValue: Double?

    @Field(key: "sort_order")
    var sortOrder: Int

    @Field(key: "is_active")
    var isActive: Bool

    /// 列名为 SQL 保留字 `description`
    @OptionalField(key: "description")
    var deviceDescription: String?

    @OptionalField(key: "created_at")
    var createdAt: Date?

    @OptionalField(key: "updated_at")
    var updatedAt: Date?

    init() {}
}
