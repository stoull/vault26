//
//  CreateDevice.swift
//  MQTTClientServer
//
//  空库初始化：创建 device（依赖 `location`）
//

import Foundation
import Fluent
import SQLKit

struct CreateDevice: AsyncMigration {
    var name: String { "CreateDevice" }

    func prepare(on database: Database) async throws {
        try await database.schema(Device.schema)
            .field("id", .int, .identifier(auto: true))
            .field("location_id", .int, .required)
            .field("name", .string, .required)
            .field("code", .string, .required)
            .field("type", .int, .required)
            .field("mqtt_topic", .string, .required)
            .field("status", .string, .required)
            .field("firmware_version", .string)
            .field("hardware_version", .string)
            .field("last_seen", .datetime)
            .field("ip_address", .string)
            .field("mac_address", .string)
            .field("is_active", .bool, .required)
            .field("sort_order", .int, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "code")
            .foreignKey(
                "location_id",
                references: Location.schema,
                "id",
                onDelete: .cascade,
                name: "fk_device_location_id"
            )
            .foreignKey(
                "type",
                references: DeviceType.schema,
                "id",
                onDelete: .restrict,
                name: "fk_device_device_type_id"
            )
            .create()

        try await Self.applyColumnComments(on: database)
    }

    func revert(on database: Database) async throws {
        try await database.schema(Device.schema).delete()
    }

    /// Fluent 建表不写 COMMENT；用 ALTER 与注释块中 `-- ...` 对齐（列类型须与 Fluent MySQL 已建列一致）
    private static func applyColumnComments(on database: Database) async throws {
        guard let sql = database as? any SQLDatabase else {
            throw CommentMigrationError.sqlDatabaseRequired
        }

        // 勿对 `location_id`、`type` 做 MODIFY：列上已有外键，MySQL 会拒绝（与 CreateLocation.parent_id 相同）。
        try await sql.raw(
            """
            ALTER TABLE `device`
              MODIFY COLUMN `name` VARCHAR(255) NOT NULL COMMENT '显示名（Living Room Env）',
              MODIFY COLUMN `code` VARCHAR(255) NOT NULL COMMENT '唯一标识（env_001）',
              MODIFY COLUMN `mqtt_topic` VARCHAR(255) NOT NULL COMMENT 'MQTT 前缀（home/livingroom/env/001）',
              MODIFY COLUMN `status` VARCHAR(255) NOT NULL COMMENT 'online/offline/error'
            """
        ).run()
    }

    private enum CommentMigrationError: Error {
        case sqlDatabaseRequired
    }
}
