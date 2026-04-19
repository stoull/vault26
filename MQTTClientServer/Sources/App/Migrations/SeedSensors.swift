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
        let code: String
        let name: String
        let sensorTypeCode: String
        let unit: String?
        let mqttField: String?
        let precisionVal: Int
        let sortOrder: Int
        let deviceCode: String?  // 所属设备 这个传感器可能不属于任何设备
        let edgeDeviceId: Int?   // 所属边缘设备 这个传感器可能不属于任何边缘设备
    }

    /// 与 `home/.../env/<sensor 段>/...` 中常用数字段及 JSON `type` 对齐
    private static let sensorRows: [SensorRow] = [
        SensorRow(code: "dht22_1", name: "客厅环境 1 号位", sensorTypeCode: "dht22", unit: "°C/%", mqttField: "temp", precisionVal: 2, sortOrder: 0, deviceCode: nil, edgeDeviceId: 4),
        SensorRow(code: "dht22_2", name: "客厅环境 2 号位", sensorTypeCode: "dht22", unit: "°C/%", mqttField: "temp", precisionVal: 2, sortOrder: 0, deviceCode: nil, edgeDeviceId: 3),
        SensorRow(code: "dht22_3", name: "客厅环境 3 号位", sensorTypeCode: "dht22", unit: "°C/%", mqttField: "temp", precisionVal: 2, sortOrder: 0, deviceCode: nil, edgeDeviceId: 0),
        SensorRow(code: "dht22_4", name: "客厅环境 4 号位", sensorTypeCode: "dht22", unit: "°C/%", mqttField: "temp", precisionVal: 2, sortOrder: 0, deviceCode: nil, edgeDeviceId: 0),
        SensorRow(code: "dht22_5", name: "客厅环境 5 号位", sensorTypeCode: "dht22", unit: "°C/%", mqttField: "temp", precisionVal: 2, sortOrder: 0, deviceCode: nil, edgeDeviceId: 0),
        SensorRow(code: "dht22_6", name: "客厅环境 6 号位", sensorTypeCode: "dht22", unit: "°C/%", mqttField: "temp", precisionVal: 2, sortOrder: 0, deviceCode: nil, edgeDeviceId: 0),
        SensorRow(code: "sht30_1", name: "客厅环境 7 号位", sensorTypeCode: "sht30", unit: "°C/%", mqttField: "temp", precisionVal: 2, sortOrder: 0, deviceCode: nil, edgeDeviceId: 4),
        SensorRow(code: "sht30_2", name: "客厅环境 8 号位", sensorTypeCode: "sht30", unit: "°C / %", mqttField: "temp", precisionVal: 2, sortOrder: 1, deviceCode: nil, edgeDeviceId: 3),
        SensorRow(code: "sht30_3", name: "客厅环境 9 号位", sensorTypeCode: "sht30", unit: "°C/%", mqttField: "temp", precisionVal: 2, sortOrder: 0, deviceCode: nil, edgeDeviceId: 0),
        SensorRow(code: "sht30_4", name: "客厅环境 10 号位", sensorTypeCode: "sht30", unit: "°C / %", mqttField: "temp", precisionVal: 2, sortOrder: 1, deviceCode: nil, edgeDeviceId: 0),
        SensorRow(code: "sht30_5", name: "客厅环境 11 号位", sensorTypeCode: "sht30", unit: "°C/%", mqttField: "temp", precisionVal: 2, sortOrder: 0, deviceCode: nil, edgeDeviceId: 0),
        SensorRow(code: "sht30_6", name: "客厅环境 12 号位", sensorTypeCode: "sht30", unit: "°C / %", mqttField: "temp", precisionVal: 2, sortOrder: 1, deviceCode: nil,edgeDeviceId: 0)
    ]

    private static var seededKeys: [(edgeDeviceId: Int?, sensor: String)] {
        sensorRows.map { ($0.edgeDeviceId, $0.code) }
    }

    func prepare(on database: Database) async throws {
        for row in Self.sensorRows {
            var deviceId = 0
            if let deviceCode = row.deviceCode, 
                let dev = try await Device.query(on: database).filter(\.$code == deviceCode).first() {
                deviceId = dev.id!
            }
            var eDevId = 0
            if let edgeDeviceId = row.edgeDeviceId,
                let edev = try await EdgeDevice.query(on: database).filter(\.$id == edgeDeviceId).first() {
                eDevId = edev.id!
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
            s.edgeDeviceId = eDevId
            s.deviceId = deviceId
            try await s.save(on: database)
        }
    }

    func revert(on database: Database) async throws {
        for key in Self.seededKeys {
            guard let dev = try await EdgeDevice.query(on: database).filter(\.$id == key.edgeDeviceId ?? 0).first(),
                  let edgeDeviceId = dev.id
            else { continue }
            try await Sensor.query(on: database)
                .filter(\.$edgeDeviceId == edgeDeviceId)
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
