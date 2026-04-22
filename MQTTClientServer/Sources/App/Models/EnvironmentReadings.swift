//
//  EnvironmentReadings.swift
//  MQTTClientServer
//
//  Created by Hut on 2026/4/20.
//

import Foundation
import Fluent

/// 环境设备上报时序数据（温湿度、光照、空气质量等）
final class EnvironmentReadings: Model, @unchecked Sendable {
    static let schema = "environment_readings"

    @ID(custom: "id", generatedBy: .database)
    var id: Int?

    @Parent(key: "location_root_id")
    var location_root: Location
    
    @Parent(key: "location_id")
    var location: Location

    @OptionalParent(key: "sensor_id")
    var sensor: Sensor?

    @OptionalField(key: "sensor_type")
    var sensorType: Int?

    @OptionalField(key: "temperature")
    var temperature: Double?

    @OptionalField(key: "humidity")
    var humidity: Double?

    @OptionalField(key: "illuminance")
    var illuminance: Double?

    @OptionalField(key: "pm25")
    var pm25: Double?

    @OptionalField(key: "co2")
    var co2: Double?

    @OptionalField(key: "hcho")
    var hcho: Double?

    @OptionalField(key: "tvoc")
    var tvoc: Double?

    @OptionalField(key: "pressure")
    var pressure: Double?

    @OptionalField(key: "smoke_gas")
    var smokeGas: Double?

    @Field(key: "created_at")
    var createdAt: Date

    @Field(key: "created_at_iso")
    var createdAtISO: String

    @Timestamp(key: "received_at", on: .create)
    var receivedAt: Date?

    init() {}

    init(
        locationRootId: Int,
        locationId: Int,
        sensorId: Int? = nil,
        sensorType: Int? = nil,
        temperature: Double? = nil,
        humidity: Double? = nil,
        illuminance: Double? = nil,
        pm25: Double? = nil,
        co2: Double? = nil,
        hcho: Double? = nil,
        tvoc: Double? = nil,
        pressure: Double? = nil,
        smokeGas: Double? = nil,
        createdAtISO: String?
    ) {
        self.$location_root.id = locationRootId
        self.$location.id = locationId
        self.$sensor.id = sensorId
        self.sensorType = sensorType
        self.temperature = temperature
        self.humidity = humidity
        self.illuminance = illuminance
        self.pm25 = pm25
        self.co2 = co2
        self.hcho = hcho
        self.tvoc = tvoc
        self.pressure = pressure
        self.smokeGas = smokeGas

        var createdDate = Date()
        if let rawISO = createdAtISO,
           let parsed = iso8601ToMySQLTimestampNoMillisToDate(rawISO) {
            createdDate = parsed
            self.createdAtISO = rawISO
        } else {
            self.createdAtISO = ISO8601DateFormatter().string(from: createdDate)
            logger.warning("Invalid ISO 8601 date string: \(createdAtISO ?? "")")
        }

        self.createdAt = createdDate
    }
}
