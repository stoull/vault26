//
//  SeedDevices.swift
//  MQTTClientServer
//
//  幂等写入若干 `device`；依赖 `CreateLocation`、`CreateDevice`、`SeedDeviceTypes`、`SeedLocation`。
//

import Foundation
import Fluent

struct SeedDevices: AsyncMigration {
    var name: String { "SeedDevices" }

    private struct DeviceRow {
        let locationCode: String
        let code: String
        let name: String
        let deviceTypeCode: String
        let mqttTopic: String
        let status: String
        let sortOrder: Int
    }

    /// 与 MQTT topic `home/<location>/env/<id>/...` 及业务命名对齐的示例设备
    private static let deviceRows: [DeviceRow] = [
        DeviceRow(
            locationCode: "livingroom",
            code: "env_001",
            name: "客厅环境站",
            deviceTypeCode: "esp32_c3_supermini",
            mqttTopic: "home/livingroom/env/001",
            status: "offline",
            sortOrder: 0
        ),
        DeviceRow(
            locationCode: "livingroom",
            code: "gateway_pi",
            name: "客厅网关（树莓派）",
            deviceTypeCode: "raspberry_pi_4_model_b",
            mqttTopic: "home/livingroom/gateway/001",
            status: "offline",
            sortOrder: 1
        ),
        DeviceRow(
            locationCode: "home",
            code: "home_hub",
            name: "家庭中枢",
            deviceTypeCode: "nanopi_r2s",
            mqttTopic: "home/home/hub/001",
            status: "offline",
            sortOrder: 0
        ),
        DeviceRow(
            locationCode: "bedroom",
            code: "env_bed_001",
            name: "卧室环境站",
            deviceTypeCode: "raspberry_pi_pico_w",
            mqttTopic: "home/bedroom/env/001",
            status: "offline",
            sortOrder: 0
        ),
    ]

    private static var seededDeviceCodes: [String] { deviceRows.map(\.code) }

    func prepare(on database: Database) async throws {
        for row in Self.deviceRows {
            if try await Device.query(on: database).filter(\.$code == row.code).first() != nil {
                continue
            }
            guard let loc = try await Location.query(on: database).filter(\.$code == row.locationCode).first(),
                  let locationId = loc.id
            else {
                throw SeedDevicesError.missingLocation(code: row.locationCode)
            }
            guard let dt = try await DeviceType.query(on: database).filter(\.$code == row.deviceTypeCode).first(),
                  let typeId = dt.id
            else {
                throw SeedDevicesError.missingDeviceType(code: row.deviceTypeCode)
            }

            let d = Device()
            d.locationId = locationId
            d.name = row.name
            d.code = row.code
            d.$deviceType.id = typeId
            d.mqttTopic = row.mqttTopic
            d.status = row.status
            d.isActive = true
            d.sortOrder = row.sortOrder
            try await d.save(on: database)
        }
    }

    func revert(on database: Database) async throws {
        for code in Self.seededDeviceCodes {
            try await Device.query(on: database).filter(\.$code == code).delete()
        }
    }

    private enum SeedDevicesError: Error, CustomStringConvertible {
        case missingLocation(code: String)
        case missingDeviceType(code: String)

        var description: String {
            switch self {
            case .missingLocation(let c): return "SeedDevices: no location with code=\(c); run SeedLocation first."
            case .missingDeviceType(let c): return "SeedDevices: no device_type with code=\(c)"
            }
        }
    }
}
