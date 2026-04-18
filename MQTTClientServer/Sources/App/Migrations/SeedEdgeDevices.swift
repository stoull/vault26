//
//  SeedEdgeDevices.swift
//  MQTTClientServer
//
//  向 `edge_device` 写入与历史示例一致的数据；依赖 `CreateEdgeDevice`、`SeedDeviceTypes`。
//  旧列 `device_type` 整型语义 → `device_type.code`，见 `legacyDeviceTypeToCode`。
//

import Foundation
import Fluent

struct SeedEdgeDevices: AsyncMigration {
    var name: String { "SeedEdgeDevices" }

    /// 旧 `edge_device.device_type` 数值 → `SeedDeviceTypes` 中的 `device_type.code`
    private static func legacyDeviceTypeToCode(_ legacy: Int) -> String {
        switch legacy {
        case 1: return "raspberry_pi_pico_w"
        case 2: return "raspberry_pi_4_model_b"
        case 3: return "esp32_c3_supermini"
        case 4: return "nanopi_r2"
        case 6: return "nanopi_r2s"
        case 7: return "imac_24_inch_m1_2021"
        case 8: return "24_inch_m2_2023"
        default: return "raspberry_pi_pico_w"
        }
    }

    private static let timestampFormat: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    private static func parseStamp(_ s: String) -> Date {
        Self.timestampFormat.date(from: s) ?? Date()
    }

    private struct Row {
        let uniqueId: String
        let legacyDeviceType: Int
        let deviceName: String?
        let description: String?
        let location: String?
        let groupName: String?
        let createdAt: String
        let lastSeen: String
        let isActive: Int
    }

    private static let rows: [Row] = [
        Row(
            uniqueId: "1000000009454311",
            legacyDeviceType: 2,
            deviceName: "Raspberry Pi 4 Model B Rev 1.4",
            description: "my first raspberry pi",
            location: "with me",
            groupName: "my devices",
            createdAt: "2026-01-14 06:27:18",
            lastSeen: "2026-01-14 06:27:18",
            isActive: 1
        ),
        Row(
            uniqueId: "e6632c8593745230",
            legacyDeviceType: 1,
            deviceName: "Raspberry Pi Pico W",
            description: "温度监控节点",
            location: "实验室A",
            groupName: "物联网传感器",
            createdAt: "2026-01-14 06:27:18",
            lastSeen: "2026-01-14 06:27:18",
            isActive: 1
        ),
        Row(
            uniqueId: "D83BDAE410F8",
            legacyDeviceType: 3,
            deviceName: "MakerGO ESP32 C3 SuperMini",
            description: "my first esp32",
            location: "Its mine",
            groupName: "my devices",
            createdAt: "2026-01-14 06:27:18",
            lastSeen: "2026-01-14 06:27:18",
            isActive: 1
        ),
        Row(
            uniqueId: "change_to_unique_id_1",
            legacyDeviceType: 4,
            deviceName: "for future use",
            description: nil,
            location: nil,
            groupName: nil,
            createdAt: "2026-01-14 06:27:18",
            lastSeen: "2026-01-14 06:27:18",
            isActive: 1
        ),
        Row(
            uniqueId: "change_to_unique_id_2",
            legacyDeviceType: 6,
            deviceName: "for future use",
            description: nil,
            location: nil,
            groupName: nil,
            createdAt: "2026-01-14 06:27:18",
            lastSeen: "2026-01-14 06:27:18",
            isActive: 1
        ),
        Row(
            uniqueId: "change_to_unique_id_3",
            legacyDeviceType: 7,
            deviceName: "for future use",
            description: nil,
            location: nil,
            groupName: nil,
            createdAt: "2026-01-14 06:27:18",
            lastSeen: "2026-01-14 06:27:18",
            isActive: 1
        ),
        Row(
            uniqueId: "change_to_unique_id_4",
            legacyDeviceType: 8,
            deviceName: "for future use",
            description: nil,
            location: nil,
            groupName: nil,
            createdAt: "2026-01-14 06:27:18",
            lastSeen: "2026-01-14 06:27:18",
            isActive: 1
        ),
    ]

    private static var seededUniqueIds: [String] { rows.map(\.uniqueId) }

    func prepare(on database: Database) async throws {
        for row in Self.rows {
            if try await EdgeDevice.query(on: database).filter(\.$uniqueId == row.uniqueId).first() != nil {
                continue
            }
            let code = Self.legacyDeviceTypeToCode(row.legacyDeviceType)
            guard let typeRow = try await DeviceType.query(on: database).filter(\.$code == code).first(),
                  let typeId = typeRow.id
            else {
                throw SeedEdgeDevicesError.missingDeviceType(code: code)
            }

            let device = EdgeDevice()
            device.uniqueId = row.uniqueId
            device.$deviceType.id = typeId
            device.deviceName = row.deviceName
            device.deviceDescription = row.description
            device.location = row.location
            device.groupName = row.groupName
            device.createdAt = Self.parseStamp(row.createdAt)
            device.lastSeen = Self.parseStamp(row.lastSeen)
            device.isActive = row.isActive
            try await device.save(on: database)
        }
    }

    func revert(on database: Database) async throws {
        for uid in Self.seededUniqueIds {
            try await EdgeDevice.query(on: database).filter(\.$uniqueId == uid).delete()
        }
    }

    private enum SeedEdgeDevicesError: Error, CustomStringConvertible {
        case missingDeviceType(code: String)

        var description: String {
            switch self {
            case .missingDeviceType(let code):
                return "SeedEdgeDevices: no device_type row with code=\(code); run SeedDeviceTypes first."
            }
        }
    }
}
