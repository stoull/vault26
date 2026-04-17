//
//  File.swift
//  MQTTClientServer
//
//  Created by Hut on 2026/4/10.
//

import Foundation
import Fluent

struct CreateSensorDataTempHumi: AsyncMigration {
    // Provide an explicit name to avoid unstable default names
    var name: String { "CreateSensorData" }

    func prepare(on database: Database) async throws {
        try await database.schema(SensorDataTempHumi.schema)
            .field("id",            .int,   .identifier(auto: true))
            .field("sensor_type",   .int)
            .field("sensor_id",     .int, .required)
            .field("temperature",   .double)
            .field("humidity",      .double)
            .field("created_at",    .datetime, .required)
            .field("created_at_iso",.string, .required)
            .field("received_at",   .datetime, .required)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(SensorDataTempHumi.schema).delete()
    }
}
