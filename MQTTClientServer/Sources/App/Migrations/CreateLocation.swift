//
//  CreateLocation.swift
//  MQTTClientServer
//
//  空库初始化：创建 location（空间树，与 `Location` 模型一致）
//

import Foundation
import Fluent
import SQLKit


struct CreateLocation: AsyncMigration {
    var name: String { "CreateLocation" }

    func prepare(on database: Database) async throws {
        try await database.schema(Location.schema)
            .field("id", .int, .identifier(auto: true))
            .field("name", .string, .required)
            .field("code", .string, .required)
            .field("parent_id", .int)
            .field("type", .string, .required)
            .field("description", .string)
            .field("sort_order", .int, .required)
            .field("is_active", .bool, .required)
            .field("mqtt_topic_prefix", .string)
            .field("latitude", .double)
            .field("longitude", .double)
            .field("address", .string)
            .field("timezone", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "code")
            .foreignKey(
                "parent_id",
                references: Location.schema,
                "id",
                onDelete: .setNull,
                name: "fk_location_parent_id"
            )
            .create()

        try await Self.applyColumnComments(on: database)
    }

    func revert(on database: Database) async throws {
        try await database.schema(Location.schema).delete()
    }

    /// Fluent 建表不写 COMMENT；用 ALTER 与注释块中 `-- ...` 对齐（列类型须与 Fluent MySQL 已建列一致）
    private static func applyColumnComments(on database: Database) async throws {
        guard let sql = database as? any SQLDatabase else {
            throw CommentMigrationError.sqlDatabaseRequired
        }

        // 不能对 `parent_id` 做 MODIFY：列已被自引用外键 `fk_location_parent_id` 使用，MySQL 会报
        // "Cannot change column 'parent_id': used in a foreign key constraint"。COMMENT 仅加在无 FK 绑定的列上。
        try await sql.raw(
            """
            ALTER TABLE `location`
              MODIFY COLUMN `name` VARCHAR(255) NOT NULL COMMENT '显示名称（Living Room）',
              MODIFY COLUMN `code` VARCHAR(128) NOT NULL COMMENT '唯一编码（livingroom）',
              MODIFY COLUMN `type` VARCHAR(255) NOT NULL COMMENT '类型（home/room/building）'
            """
        ).run()
    }

    private enum CommentMigrationError: Error {
        case sqlDatabaseRequired
    }
}
