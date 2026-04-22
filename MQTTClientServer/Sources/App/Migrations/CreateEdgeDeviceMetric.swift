//
//  CreateEdgeDeviceMetric.swift
//  MQTTClientServer
//
//  空库初始化：创建 edge_device_metric
//

import Foundation
import Fluent
import SQLKit

struct CreateEdgeDeviceMetric: AsyncMigration {
    var name: String { "CreateEdgeDeviceMetric" }

    func prepare(on database: Database) async throws {
        try await database.schema(EdgeDeviceMetric.schema)
            .field("id", .int, .identifier(auto: true))
            .field("location_root_id", .int)
            .field("location_id", .int)
            .field("device_id", .int)
            .field("created_at_iso", .string)
            .field("timestamp", .datetime, .required)
            .field("platform", .string)
            .field("os_version", .string)
            .field("cpu_frequency_mhz", .int)
            .field("cpu_temperature", .double)
            .field("total_storage_bytes", .int64)
            .field("used_storage_bytes", .int64)
            .field("free_storage_bytes", .int64)
            .field("storage_usage_percent", .double)
            .field("total_memory_bytes", .int64)
            .field("used_memory_bytes", .int64)
            .field("free_memory_bytes", .int64)
            .field("memory_usage_percent", .double)
            .field("uptime_seconds", .int64)
            .field("reset_reason", .int, .required)
            .field("battery_level_percent", .double)
            .field("ip", .string)
            .field("mac", .string)
            .field("subnet", .string)
            .field("dns", .string)
            .field("gateway", .string)
            .field("rssi", .int)
            .field("extra_data", .json)
            .foreignKey(
                "location_root_id",
                references: Location.schema,
                "id",
                onDelete: .cascade,
                name: "fk_edge_device_metric_location_root_id"
            )
            .foreignKey(
                "location_id",
                references: Location.schema,
                "id",
                onDelete: .cascade,
                name: "fk_edge_device_metric_location_id"
            )
            .foreignKey(
                "device_id",
                references: EdgeDevice.schema,
                "id",
                onDelete: .cascade,
                name: "fk_edge_device_metric_device_id"
            )
            .create()

        // Fluent schema API 不生成列 COMMENT；用 ALTER 与 SQLAlchemy 的 comment= 对齐（类型与 Fluent MySQL 委托一致）
        try await Self.applyColumnComments(on: database)
    }

    func revert(on database: Database) async throws {
        try await database.schema(EdgeDeviceMetric.schema).delete()
    }

    /// 为带 `comment=` 的列写入 MySQL `COMMENT`（列类型须与 Fluent 已建表一致）
    private static func applyColumnComments(on database: Database) async throws {
        guard let sql = database as? any SQLDatabase else {
            throw CommentMigrationError.sqlDatabaseRequired
        }

        try await sql.raw(
            """
            ALTER TABLE `edge_device_metric`
              MODIFY COLUMN `total_storage_bytes` BIGINT NULL COMMENT '总存储空间（字节）',
              MODIFY COLUMN `used_storage_bytes` BIGINT NULL COMMENT '已用存储（字节）',
              MODIFY COLUMN `free_storage_bytes` BIGINT NULL COMMENT '剩余存储（字节）',
              MODIFY COLUMN `storage_usage_percent` DOUBLE NULL COMMENT '存储使用率（%）',
              MODIFY COLUMN `total_memory_bytes` BIGINT NULL COMMENT '总内存（字节）',
              MODIFY COLUMN `used_memory_bytes` BIGINT NULL COMMENT '已用内存（字节）',
              MODIFY COLUMN `free_memory_bytes` BIGINT NULL COMMENT '剩余内存（字节）',
              MODIFY COLUMN `memory_usage_percent` DOUBLE NULL COMMENT '内存使用率（%）',
              MODIFY COLUMN `reset_reason` BIGINT NOT NULL COMMENT '设备类型:  0=上电复位, 1=看门狗复位....'
            """
        ).run()
    }

    private enum CommentMigrationError: Error {
        case sqlDatabaseRequired
    }
}
