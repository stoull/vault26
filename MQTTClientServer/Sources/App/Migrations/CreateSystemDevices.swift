//
//  CreateSystemDevices.swift
//  MQTTClientServer
//
//  空库初始化：创建 system_devices
//

import Foundation
import Fluent
import SQLKit

struct CreateSystemDevices: AsyncMigration {
    var name: String { "CreateSystemDevices" }

    func prepare(on database: Database) async throws {
        try await database.schema(SystemDevice.schema)
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
            .create()

        // Fluent schema API 不生成列 COMMENT；用 ALTER 与 SQLAlchemy 的 comment= 对齐（类型与 Fluent MySQL 委托一致）
        try await Self.applyColumnComments(on: database)
    }

    func revert(on database: Database) async throws {
        try await database.schema(SystemDeviceSnapshot.schema).delete()
    }

    /// 为带 `comment=` 的列写入 MySQL `COMMENT`（列类型须与 Fluent 已建表一致）
    private static func applyColumnComments(on database: Database) async throws {
        guard let sql = database as? any SQLDatabase else {
            throw CommentMigrationError.sqlDatabaseRequired
        }

        try await sql.raw(
            """
            ALTER TABLE `system_devices`
              MODIFY COLUMN `device_type` BIGINT NOT NULL COMMENT '设备类型:  1=Pico W, 2=树莓派, 3=ESP32.. .'
            """
        ).run()
    }

    private enum CommentMigrationError: Error {
        case sqlDatabaseRequired
    }
}
