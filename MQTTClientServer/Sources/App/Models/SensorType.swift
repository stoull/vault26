//
//  SensorType.swift
//  MQTTClientServer
//
//  Created by Hut on 2026/4/18.
//

import Foundation
import Fluent


final class SensorType: Model, @unchecked Sendable {
    static let schema = "sensor_type"

    @ID(custom: "id", generatedBy: .database)
    var id: Int?

    @Field(key: "name")
    var name: String

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
