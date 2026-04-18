//
//  CreateSensor.swift
//  MQTTClientServer
//
//  空库初始化：创建 sensor（依赖 `device`）
//

import Foundation
import Fluent
import SQLKit

struct CreateSensor: AsyncMigration {
    var name: String { "CreateSensor" }

    func prepare(on database: Database) async throws {
        try await database.schema(Sensor.schema)
            .field("id", .int, .identifier(auto: true))
            .field("device_id", .int, .required)
            .field("name", .string, .required)
            .field("code", .string, .required)
            .field("type", .int, .required)
            .field("unit", .string)
            .field("mqtt_field", .string)
            .field("precision_val", .int, .required)
            .field("min_value", .double)
            .field("max_value", .double)
            .field("sort_order", .int, .required)
            .field("is_active", .bool, .required)
            .field("description", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "device_id", "code")
            .foreignKey(
                "device_id",
                references: Device.schema,
                "id",
                onDelete: .cascade,
                name: "fk_sensor_device_id"
            )
            .foreignKey(
                "type",
                references: SensorType.schema,
                "id",
                onDelete: .restrict,
                name: "fk_sensor_sensor_type_id"
            )
            .create()

        try await Self.applyColumnComments(on: database)
    }

    func revert(on database: Database) async throws {
        try await database.schema(Sensor.schema).delete()
    }

    /// Fluent 建表不写 COMMENT；用 ALTER 与注释块中 `-- ...` 对齐（列类型须与 Fluent MySQL 已建列一致）
    private static func applyColumnComments(on database: Database) async throws {
        guard let sql = database as? any SQLDatabase else {
            throw CommentMigrationError.sqlDatabaseRequired
        }

        // 勿对 `device_id`、`type` 做 MODIFY：外键列，MySQL 会拒绝。
        try await sql.raw(
            """
            ALTER TABLE `sensor`
              MODIFY COLUMN `name` VARCHAR(255) NOT NULL COMMENT '显示名（Temperature）',
              MODIFY COLUMN `code` VARCHAR(255) NOT NULL COMMENT '唯一标识（temperature）',
              MODIFY COLUMN `unit` VARCHAR(255) NULL COMMENT '单位（°C/%）'
            """
        ).run()
    }

    private enum CommentMigrationError: Error {
        case sqlDatabaseRequired
    }
}
