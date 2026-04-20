//
//  AddSensorTypeToSensorDataTempHumi.swift
//  MQTTClientServer
//
//  Created by Codex on 2026/4/16.
//

import Foundation
import Fluent

// 这是一个新增字段的示例，不要调用这个struct

/// 向已存在的 device_type 表补充 xxxx_key 字段
struct AddXXXToDeviceType: AsyncMigration {
    var name: String { "AddXXXToDeviceType" }

    func prepare(on database: Database) async throws {
        try await database.schema(DeviceType.schema)
            .field("xxxx_key", .int)
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema(DeviceType.schema)
            .deleteField("xxxx_key")
            .update()
    }
}
