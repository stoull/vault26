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
            .field("code", .string, .required)
            .field("device_type", .int, .required)
            .field("device_name", .string)
            .field("description", .string)
            .field("location_id", .int, .required)
            .field("group_name", .string)
            .field("mqtt_topic", .string, .required)
            .field("status", .string, .required)
            .field("firmware_version", .string)
            .field("hardware_version", .string)
            .field("created_at", .datetime, .required)
            .field("last_seen", .datetime, .required)
            .field("updated_at", .datetime)
            .field("ip_address", .string)
            .field("mac_address", .string)
            .field("is_active", .int, .required)
            .field("sort_order", .int, .required)
            .unique(on: "unique_id", "code")
            .foreignKey(
                "location_id",
                references: Location.schema,
                "id",
                onDelete: .cascade,
                name: "fk_edge_device_location_id"
            )
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
