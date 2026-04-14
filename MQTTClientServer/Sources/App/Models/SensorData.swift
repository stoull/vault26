//
//  SensorData.swift
//  MQTTClientServer
//
//  Created by Hut on 2026/4/10.
//

import Foundation
import Fluent

/// 映射到 MariaDB 的 sensor_data 表
final class SensorData: Model, @unchecked Sendable {
    static let schema = "sensor_data"

    @ID(custom: "id", generatedBy: .database)
    var id: Int?

    @Field(key: "topic")
    var topic: String

    @Field(key: "payload")
    var payload: String          // 原始 JSON 字符串

    @Field(key: "temperature")
    var temperature: Double?

    @Field(key: "humidity")
    var humidity: Double?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(topic: String, payload: String,
         temperature: Double? = nil, humidity: Double? = nil) {
        self.topic = topic
        self.payload = payload
        self.temperature = temperature
        self.humidity = humidity
    }
}
