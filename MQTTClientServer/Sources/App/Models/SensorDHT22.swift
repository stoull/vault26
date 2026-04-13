//
//  File.swift
//  MQTTClientServer
//
//  Created by Hut on 2026/4/10.
//

import Foundation
import Fluent

final class SensorDHT22: Model, @unchecked Sendable {
    static let schema = "sensor_dht22"

    @ID(custom: "id", generatedBy: .database)
    var id: Int?

    @Field(key: "sensor_id")
    var sensorId: String

    @Field(key: "temperature")
    var temperature: Double

    @Field(key: "humidity")
    var humidity: Double

    @Field(key: "created_at")
    var createdAt: Int        // Unix 时间戳（秒）

    @Field(key: "created_at_iso")
    var createdAtISO: String  // e.g. "2026-04-10T12:00:00+08:00"

    init() {}

    init(
        sensorId: String,
        temperature: Double,
        humidity: Double,
        createdAt: Int,
        createdAtISO: String
    ) {
        self.sensorId = sensorId
        self.temperature = temperature
        self.humidity = humidity
        self.createdAt = createdAt
        self.createdAtISO = createdAtISO
    }
}
