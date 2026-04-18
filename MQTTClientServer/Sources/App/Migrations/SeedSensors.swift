//
//  SeedSensors.swift
//  MQTTClientServer
//
//  幂等写入若干 `sensor`（按所属 `device.code` 与 `sensor_type.code` 解析）；依赖 `CreateSensor`、`SeedSensorTypes`、`SeedDevices`。
//

import Foundation
import Fluent

struct SeedSensors: AsyncMigration {
    var name: String { "SeedSensors" }

    private struct SensorRow {
        let deviceCode: String
        let code: String
        let name: String
        let sensorTypeCode: String
        let unit: String?
        let mqttField: String?
        let precisionVal: Int
        let sortOrder: Int
    }

    /// 与 `home/.../env/<sensor 段>/...` 中常用数字段及 JSON `type` 对齐
    private static let sensorRows: [SensorRow] = [
        SensorRow(
            deviceCode: "env_001",
            code: "1",
            name: "客厅环境 1 号位",
            sensorTypeCode: "sht30",
            unit: "°C / %",
            mqttField: "temp",
            precisionVal: 2,
            sortOrder: 0
        ),
        SensorRow(
            deviceCode: "env_001",
            code: "2",
            name: "客厅环境 2 号位",
            sensorTypeCode: "sht30",
            unit: "°C / %",
            mqttField: "temp",
            precisionVal: 2,
            sortOrder: 1
        ),
        SensorRow(
            deviceCode: "gateway_pi",
            code: "1",
            name: "网关机载 BME280",
            sensorTypeCode: "bme280",
            unit: "°C / % / hPa",
            mqttField: nil,
            precisionVal: 2,
            sortOrder: 0
        ),
        SensorRow(
            deviceCode: "env_bed_001",
            code: "1",
            name: "卧室环境 1 号位",
            sensorTypeCode: "aht20",
            unit: "°C / %",
            mqttField: nil,
            precisionVal: 2,
            sortOrder: 0
        ),
    ]

    private static var seededKeys: [(device: String, sensor: String)] {
        sensorRows.map { ($0.deviceCode, $0.code) }
    }

    func prepare(on database: Database) async throws {
        for row in Self.sensorRows {
            guard let dev = try await Device.query(on: database).filter(\.$code == row.deviceCode).first(),
                  let deviceId = dev.id
            else {
                throw SeedSensorsError.missingDevice(code: row.deviceCode)
            }
            if try await Sensor.query(on: database)
                .filter(\.$deviceId == deviceId)
                .filter(\.$code == row.code)
                .first() != nil
            {
                continue
            }
            guard let st = try await SensorType.query(on: database).filter(\.$code == row.sensorTypeCode).first(),
                  let typeId = st.id
            else {
                throw SeedSensorsError.missingSensorType(code: row.sensorTypeCode)
            }

            let s = Sensor()
            s.deviceId = deviceId
            s.name = row.name
            s.code = row.code
            s.$sensorType.id = typeId
            s.unit = row.unit
            s.mqttField = row.mqttField
            s.precisionVal = row.precisionVal
            s.sortOrder = row.sortOrder
            s.isActive = true
            try await s.save(on: database)
        }
    }

    func revert(on database: Database) async throws {
        for key in Self.seededKeys {
            guard let dev = try await Device.query(on: database).filter(\.$code == key.device).first(),
                  let deviceId = dev.id
            else { continue }
            try await Sensor.query(on: database)
                .filter(\.$deviceId == deviceId)
                .filter(\.$code == key.sensor)
                .delete()
        }
    }

    private enum SeedSensorsError: Error, CustomStringConvertible {
        case missingDevice(code: String)
        case missingSensorType(code: String)

        var description: String {
            switch self {
            case .missingDevice(let c): return "SeedSensors: no device with code=\(c); run SeedDevices first."
            case .missingSensorType(let c): return "SeedSensors: no sensor_type with code=\(c); run SeedSensorTypes first."
            }
        }
    }
}
