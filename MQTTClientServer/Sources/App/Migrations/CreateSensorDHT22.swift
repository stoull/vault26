//
//  File.swift
//  MQTTClientServer
//
//  Created by Hut on 2026/4/10.
//

import Foundation
import Fluent

struct CreateSensorDHT22: AsyncMigration {
    var name: String { "CreateSensorDHT22" }

    func prepare(on database: Database) async throws {
        try await database.schema(SensorDHT22.schema)
            .field("id",             .int,    .identifier(auto: true))
            .field("sensor_id",      .string, .required)
            .field("temperature",    .double, .required)
            .field("humidity",       .double, .required)
            .field("created_at",     .int,    .required)   // Unix timestamp
            .field("created_at_iso", .string, .required)   // ISO 8601
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(SensorDHT22.schema).delete()
    }
}
