//
//  CreateSystemDevices.swift
//  MQTTClientServer
//
//  空库初始化：创建 edge_device
//

import Foundation
import Fluent

struct CreateEdgeDevice: AsyncMigration {
    var name: String { "CreateEdgeDevice" }

    func prepare(on database: Database) async throws {
        try await database.schema(EdgeDevice.schema)
            .field("id", .int, .identifier(auto: true))
            .field("unique_id", .string, .required)
            .field("device_type", .int, .required)
            .field("device_name", .string)
            .field("description", .string)
            .field("location", .string)
            .field("group_name", .string)
            .field("created_at", .datetime, .required)
            .field("last_seen", .datetime, .required)
            .field("is_active", .int, .required)
            .unique(on: "unique_id")
            .foreignKey(
                "device_type",
                references: DeviceType.schema,
                "id",
                onDelete: .restrict,
                name: "fk_edge_device_device_type_id"
            )
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(EdgeDevice.schema).delete()
    }
}
