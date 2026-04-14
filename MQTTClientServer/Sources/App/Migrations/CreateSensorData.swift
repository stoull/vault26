//
//  File.swift
//  MQTTClientServer
//
//  Created by Hut on 2026/4/10.
//

import Foundation
import Fluent

struct CreateSensorData: AsyncMigration {
    // Provide an explicit name to avoid unstable default names
    var name: String { "CreateSensorData" }

    func prepare(on database: Database) async throws {
        try await database.schema(SensorData.schema)
            .field("id",             .int,    .identifier(auto: true))
            .field("topic",        .string,   .required)
            .field("payload",      .string,   .required)
            .field("temperature",  .double)
            .field("humidity",     .double)
            .field("created_at",   .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(SensorData.schema).delete()
    }
}
