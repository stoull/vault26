//
//  CreateDeviceType.swift
//  MQTTClientServer
//
//  空库初始化：创建 device_type
//

import Foundation
import Fluent
import SQLKit

struct CreateDeviceType: AsyncMigration {
    var name: String { "CreateDeviceType" }

    func prepare(on database: Database) async throws {
        try await database.schema(DeviceType.schema)
            .field("id", .int, .identifier(auto: true))
            .field("name", .string, .required)
            .field("code", .string, .required)
            .field("description", .string)
            .field("mqtt_prefix", .string, .required)
            .field("icon", .string)
            .field("color", .string)
            .field("is_active", .bool, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "code")
            .create()

        try await Self.applyColumnComments(on: database)
    }

    func revert(on database: Database) async throws {
        try await database.schema(DeviceType.schema).delete()
    }

    /// Fluent 建表不写 COMMENT；用 ALTER 与注释块中 `-- ...` 对齐（列类型须与 Fluent MySQL 已建列一致）
    private static func applyColumnComments(on database: Database) async throws {
        guard let sql = database as? any SQLDatabase else {
            throw CommentMigrationError.sqlDatabaseRequired
        }

        try await sql.raw(
            """
            ALTER TABLE `device_type`
              MODIFY COLUMN `name` VARCHAR(255) NOT NULL COMMENT '显示名（Env Sensor）',
              MODIFY COLUMN `code` VARCHAR(255) NOT NULL COMMENT '唯一标识（env）',
              MODIFY COLUMN `mqtt_prefix` VARCHAR(255) NOT NULL COMMENT 'mqtt 分类前缀（env/light）'
            """
        ).run()
    }

    private enum CommentMigrationError: Error {
        case sqlDatabaseRequired
    }
}
