//
//  CreateDeviceSnapshots.swift
//  MQTTClientServer
//
//  空库初始化：创建 system_device_snapshots
//

import Foundation
import Fluent
import SQLKit

struct CreateDeviceSnapshots: AsyncMigration {
    var name: String { "CreateDeviceSnapshots" }
        try await database.schema(SystemDeviceSnapshot.schema)
            .field("id", .int, .identifier(auto: true))
            .field("device_id", .int, .required)
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
                "device_id",
                references: SystemDevice.schema,
                "id",
                onDelete: .cascade,
                name: "fk_system_device_snapshot_device"
            )
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
            ALTER TABLE `system_device_snapshots`
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
