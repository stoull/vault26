//
//  SeedDeviceTypes.swift
//  MQTTClientServer
//
//  在 `device_type` 中写入设备族字典；依赖 `CreateDeviceType`。
//

import Foundation
import Fluent

struct SeedDeviceTypes: AsyncMigration {
    var name: String { "SeedDeviceTypes" }

    private static let rows: [(name: String, code: String, mqttPrefix: String, description: String?)] = [
        ("iMac, 24-inch, M1, 2021", "imac_24_inch_m1_2021", "system", "iMac, 24 英寸, M1, 2021年款 Mac"),
        ("Mac mini, 2023", "24_inch_m2_2023", "system", "24 英寸, M2, 2023年款 Mac"),
        ("Raspberry Pi 4 Model B", "raspberry_pi_4_model_b", "system", "树莓派 4 型号 B"),
        ("Raspberry Pi Pico W", "raspberry_pi_pico_w", "system", "树莓派 Pico W"),
        ("ESP32 C3 SuperMini", "esp32_c3_supermini", "system", "ESP32 C3 SuperMini"),
        ("NanoPi R2", "nanopi_r2", "system", "NanoPi R2"),
        ("NanoPi R2S", "nanopi_r2s", "system", "NanoPi R2S"),
    ]

    private static var seededCodes: [String] { rows.map(\.code) }

    func prepare(on database: Database) async throws {
        for row in Self.rows {
            if try await DeviceType.query(on: database).filter(\.$code == row.code).first() != nil {
                continue
            }
            let model = DeviceType()
            model.name = row.name
            model.code = row.code
            model.mqttPrefix = row.mqttPrefix
            model.deviceDescription = row.description
            model.isActive = true
            try await model.save(on: database)
        }
    }

    func revert(on database: Database) async throws {
        for code in Self.seededCodes {
            try await DeviceType.query(on: database).filter(\.$code == code).delete()
        }
    }
}
