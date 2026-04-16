//
//  AddSensorTypeToSensorDataTempHumi.swift
//  MQTTClientServer
//
//  Created by Codex on 2026/4/16.
//

import Foundation
import Fluent

/// 向已存在的 sensor_data_temp_humi 表补充 sensor_type 字段
struct AddSensorTypeToSensorDataTempHumi: AsyncMigration {
    var name: String { "AddSensorTypeToSensorDataTempHumi" }

    func prepare(on database: Database) async throws {
        try await database.schema(SensorDataTempHumi.schema)
            .field("sensor_type", .int)
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema(SensorDataTempHumi.schema)
            .deleteField("sensor_type")
            .update()
    }
}
