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

    @Field(key: "sensor_type")
    var sensorType: Int?
    
    @Field(key: "sensor_id")
    var sensorId: Int?

    @Field(key: "temperature")
    var temperature: Double?

    @Field(key: "humidity")
    var humidity: Double?
    
    @Field(key: "created_at")
    var createdAt: String?
    
    @Timestamp(key: "received_at", on: .create)
    var receivedAt: Date?

    init() {}

    init(sensorType: Int, sensorId: Int, temperature: Double? = nil,
         humidity: Double? = nil, created_at: String?) {
        self.sensorType = sensorType
        self.sensorId = sensorId
        self.temperature = temperature
        self.humidity = humidity
        self.createdAt = created_at
    }
}
