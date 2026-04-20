//
//  CreateEnvironmentReadings.swift
//  MQTTClientServer
//
//  Created by Hut on 2026/4/20.
//

import Foundation
import Fluent

struct CreateEnvironmentReadings: AsyncMigration {
    var name: String { "CreateEnvironmentReadings" }

    func prepare(on database: Database) async throws {
        try await database.schema(EnvironmentReadings.schema)
            .field("id", .int, .identifier(auto: true))
            .field("location_id", .int, .required)
            .field("sensor_id", .int, .required)
            .field("sensor_type", .int)
            .field("temperature", .double)
            .field("humidity", .double)
            .field("illuminance", .double)
            .field("pm25", .double)
            .field("co2", .double)
            .field("hcho", .double)
            .field("tvoc", .double)
            .field("pressure", .double)
            .field("smoke_gas", .double)
            .field("created_at", .datetime, .required)
            .field("created_at_iso", .string, .required)
            .field("received_at", .datetime, .required)
            .foreignKey(
                "location_id",
                references: Location.schema,
                "id",
                onDelete: .cascade,
                name: "fk_environment_readings_location_id"
            )
            .foreignKey(
                "sensor_id",
                references: Sensor.schema,
                "id",
                onDelete: .cascade,
                name: "fk_environment_readings_sensor_id"
            )
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(EnvironmentReadings.schema).delete()
    }
}
