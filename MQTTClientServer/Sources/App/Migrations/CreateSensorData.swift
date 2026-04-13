//
//  File.swift
//  MQTTClientServer
//
//  Created by Hut on 2026/4/10.
//

import Foundation
import Fluent

struct CreateSensorData: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(SensorData.schema)
            .id()
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
