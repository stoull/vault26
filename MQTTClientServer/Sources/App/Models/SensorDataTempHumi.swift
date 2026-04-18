//
//  SensorData.swift
//  MQTTClientServer
//
//  Created by Hut on 2026/4/10.
//

import Foundation
import Fluent

/// 映射到 MariaDB 的 sensor_data 表
final class SensorDataTempHumi: Model, @unchecked Sendable {
    static let schema = "sensor_data_temp_humi"

    @ID(custom: "id", generatedBy: .database)
    var id: Int?

    @Parent(key: "location_id")
    var location: Location

    @Parent(key: "sensor_id")
    var sensor: Sensor

    @OptionalField(key: "sensor_type")
    var sensorType: Int?

    @OptionalField(key: "temperature")
    var temperature: Double?

    @OptionalField(key: "humidity")
    var humidity: Double?
    
    @Field(key: "created_at")
    var createdAt: Date
    
    @Field(key: "created_at_iso")
    var createdAtISO: String
    
    @Timestamp(key: "received_at", on: .create)
    var receivedAt: Date?

    init() {}

    init(locationId: Int, sensorId: Int, sensorType: Int = 0, temperature: Double? = nil,
         humidity: Double? = nil, created_at: String?) {
        self.$location.id = locationId
        self.$sensor.id = sensorId
        self.sensorType = sensorType
        self.temperature = temperature
        self.humidity = humidity

        self.createdAtISO = created_at ?? ""
        
        // 解析 ISO 8601 时间戳
        var cd: Date = Date()
        if let createdAtISO = created_at,
           let createdAt = iso8601ToMySQLTimestampNoMillisToDate(createdAtISO) {
            cd = createdAt
            self.createdAtISO = createdAtISO
        } else {
            self.createdAtISO = ISO8601DateFormatter().string(from: cd)
            logger.warning("Invalid ISO 8601 date string: \(created_at ?? "")")
        }
        
        self.createdAt = cd
        
    }
}
