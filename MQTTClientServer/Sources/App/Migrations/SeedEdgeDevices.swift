//
//  SeedEdgeDevices.swift
//  MQTTClientServer
//
//  向 `edge_device` 写入与历史示例一致的数据；依赖 `CreateEdgeDevice`、`SeedDeviceTypes`。
//

import Foundation
import Fluent

struct SeedEdgeDevices: AsyncMigration {
    var name: String { "SeedEdgeDevices" }

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
        let deviceTypeCode: String
        let deviceName: String?
        let description: String?
        let locationCode: String
        let groupName: String?
        let mqttTopic: String
        let status: String
        let sortOrder: Int
        let createdAt: String
        let lastSeen: String
        let isActive: Int
    }

    private static let rows: [Row] = [
        Row(
            uniqueId: "1000000009454311",
            deviceTypeCode: "raspberry_pi_4_model_b",
            deviceName: "全能家庭（树莓派）",
            description: "my first raspberry pi",
            locationCode: "unassigned",
            groupName: "my devices",
            mqttTopic: "-",
            status: "offline",
            sortOrder: 0,
            createdAt: "2026-01-14 06:27:18",
            lastSeen: "2026-01-14 06:27:18",
            isActive: 1
        ),
        Row(
            uniqueId: "e6632c8593745230",
            deviceTypeCode: "raspberry_pi_pico_w",
            deviceName: "全能设控助手",
            description: "unassigned",
            locationCode: "livingroom",
            groupName: "物联网传感器",
            mqttTopic: "-",
            status: "offline",
            sortOrder: 0,
            createdAt: "2026-01-14 06:27:18",
            lastSeen: "2026-01-14 06:27:18",
            isActive: 1
        ),
        Row(
            uniqueId: "D83BDAE410F8",
            deviceTypeCode: "esp32_c3_supermini",
            deviceName: "家庭环境监视",
            description: "my first esp32",
            locationCode: "livingroom",
            groupName: "my devices",
            mqttTopic: "-",
            status: "offline",
            sortOrder: 0,
            createdAt: "2026-01-14 06:27:18",
            lastSeen: "2026-01-14 06:27:18",
            isActive: 1
        ),
        Row(
            uniqueId: "ACA704D777EC",
            deviceTypeCode: "esp32_c3_supermini",
            deviceName: "ESP32 C3 SuperMini",
            description: "my second esp32",
            locationCode: "livingroom",
            groupName: nil,
            mqttTopic: "-",
            status: "offline",
            sortOrder: 0,
            createdAt: "2026-01-14 06:27:18",
            lastSeen: "2026-01-14 06:27:18",
            isActive: 1
        ),
        Row(
            uniqueId: "change_to_unique_id_10",
            deviceTypeCode: "esp32_c3_supermini",
            deviceName: "ESP32 C3 SuperMini",
            description: "my second esp32",
            locationCode: "unassigned",
            groupName: nil,
            mqttTopic: "-",
            status: "offline",
            sortOrder: 0,
            createdAt: "2026-01-14 06:27:18",
            lastSeen: "2026-01-14 06:27:18",
            isActive: 1
        ),
        Row(
            uniqueId: "change_to_unique_id_11",
            deviceTypeCode: "esp32_c3_supermini",
            deviceName: "ESP32 C3 SuperMini",
            description: "my second esp32",
            locationCode: "unassigned",
            groupName: nil,
            mqttTopic: "-",
            status: "offline",
            sortOrder: 0,
            createdAt: "2026-01-14 06:27:18",
            lastSeen: "2026-01-14 06:27:18",
            isActive: 1
        ),
        Row(
            uniqueId: "change_to_unique_id_12",
            deviceTypeCode: "esp32_c3_supermini",
            deviceName: "ESP32 C3 SuperMini",
            description: "my second esp32",
            locationCode: "unassigned",
            groupName: nil,
            mqttTopic: "-",
            status: "offline",
            sortOrder: 0,
            createdAt: "2026-01-14 06:27:18",
            lastSeen: "2026-01-14 06:27:18",
            isActive: 1
        ),
        Row(
            uniqueId: "change_to_unique_id_2",
            deviceTypeCode: "nanopi_r2s",
            deviceName: "全能家庭网关",
            description: "my first nanopi",
            locationCode: "livingroom",
            groupName: nil,
            mqttTopic: "-",
            status: "offline",
            sortOrder: 0,
            createdAt: "2026-01-14 06:27:18",
            lastSeen: "2026-01-14 06:27:18",
            isActive: 1
        ),
        Row(
            uniqueId: "change_to_unique_id_3",
            deviceTypeCode: "imac_24_inch_m1_2021",
            deviceName: "for future use",
            description: "des",
            locationCode: "livingroom",
            groupName: nil,
            mqttTopic: "-",
            status: "offline",
            sortOrder: 0,
            createdAt: "2026-01-14 06:27:18",
            lastSeen: "2026-01-14 06:27:18",
            isActive: 1
        )
    ]

    private static var seededUniqueIds: [String] { rows.map(\.uniqueId) }

    func prepare(on database: Database) async throws {
        for row in Self.rows {
            if try await EdgeDevice.query(on: database).filter(\.$uniqueId == row.uniqueId).first() != nil {
                continue
            }
            guard let typeRow = try await DeviceType.query(on: database).filter(\.$code == row.deviceTypeCode).first(),
                  let typeId = typeRow.id
            else {
                throw SeedEdgeDevicesError.missingDeviceType(code: row.deviceTypeCode)
            }

            guard let location = try await Location.query(on: database).filter(\.$code == row.locationCode).first(),
                  let locationId = location.id
            else {
                throw SeedEdgeDevicesError.missingLocation(code: row.locationCode)
            }

            let device = EdgeDevice()
            device.uniqueId = row.uniqueId
            device.code = generateMqttCode(deviceType: row.deviceTypeCode, uniqueId: row.uniqueId)
            device.$deviceType.id = typeId
            device.deviceName = row.deviceName
            device.deviceDescription = row.description
            device.locationId = locationId
            device.groupName = row.groupName
            device.mqttTopic = row.mqttTopic
            device.status = row.status
            device.createdAt = Self.parseStamp(row.createdAt)
            device.lastSeen = Self.parseStamp(row.lastSeen)
            device.isActive = row.isActive
            device.sortOrder = row.sortOrder
            try await device.save(on: database)
        }
    }
    
    /**
     逻辑：取设备类型前缀 + 物理ID的后4位 (类似 MAC 地址缩短版)
     结果示例：
     ESP32 C3 -> "ESP_E410F8"
     Raspberry -> "RAS_454311"
     */
    func generateMqttCode(deviceType: String, uniqueId: String) -> String {
        let prefix = deviceType.uppercased().prefix(3) // 例如 "ESP"
        
        // 取 uniqueId 的后 6 位，保证唯一性且够短
        // 假设 uniqueId 是 "D83DFAE410F8" -> 取 "E410F8"
        let suffix = uniqueId.suffix(6).uppercased()
        
        return "\(prefix)_\(suffix)"
    }

    func revert(on database: Database) async throws {
        for uid in Self.seededUniqueIds {
            try await EdgeDevice.query(on: database).filter(\.$uniqueId == uid).delete()
        }
    }

    private enum SeedEdgeDevicesError: Error, CustomStringConvertible {
        case missingDeviceType(code: String)
        case missingLocation(code: String)

        var description: String {
            switch self {
            case .missingDeviceType(let code):
                return "SeedEdgeDevices: no device_type row with code=\(code); run SeedDeviceTypes first."
            case .missingLocation(let code):
                return "SeedEdgeDevices: no location with code=\(code); run SeedLocation first."
            }
        }
    }
}
