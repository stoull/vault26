//
//  DeviceType.swift
//  MQTTClientServer
//
//  Created by Hut on 2026/4/18.
//

import Foundation
import Fluent

/**
 ```sql
 CREATE TABLE device_type (
     id BIGINT PRIMARY KEY,

     name VARCHAR(100) NOT NULL,
     code VARCHAR(100) NOT NULL UNIQUE,

     description TEXT,

     mqtt_prefix VARCHAR(100) NOT NULL,

     icon VARCHAR(50),
     color VARCHAR(20),

     is_active BOOLEAN DEFAULT TRUE,

     created_at TIMESTAMP,
     updated_at TIMESTAMP
 );
 ```
 */
/// 设备类型字典（MQTT 前缀、UI 元数据等），对应表 `device_type`
final class DeviceType: Model, @unchecked Sendable {
    static let schema = "device_type"

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
