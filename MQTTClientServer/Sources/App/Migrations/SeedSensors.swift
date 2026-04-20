//
//  SeedSensors.swift
//  MQTTClientServer
//
//  幂等写入若干 `sensor`（按 `edge_device_id` 与 `sensor_type.code` 解析）；依赖 `CreateSensor`、`SeedSensorTypes`、`SeedEdgeDevices`。
//

import Foundation
import Fluent

struct SeedSensors: AsyncMigration {
    var name: String { "SeedSensors" }

    private static let timestampFormat: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    /// `nil`、空串或无法解析时返回 `nil`
    private static func parseStamp(_ s: String?) -> Date? {
        guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        return timestampFormat.date(from: s)
    }

    private struct SensorRow {
        let code: String
        let name: String
        let sensorTypeCode: String
        let unit: String?
        let mqttField: String?
        let precisionVal: Int
        let sortOrder: Int
        let edgeDeviceId: Int?
        let description: String?
        let createdAt: String?
        let updatedAt: String?
        let isActive: Bool
    }

    /// 与 `home/.../env/<sensor 段>/...` 中常用数字段及 JSON `type` 对齐
    private static let sensorRows: [SensorRow] = [
        SensorRow(code: "dht22_1", name: "客厅环境-已损坏", sensorTypeCode: "dht22", unit: "°C/%", mqttField: "temp", precisionVal: 2, sortOrder: 0, edgeDeviceId: 4, description: "已损坏", createdAt: "2024-08-20 06:27:18", updatedAt: "2025-08-20 06:27:18", isActive: false),
        SensorRow(code: "dht22_2", name: "客厅环境 1 号位", sensorTypeCode: "dht22", unit: "°C/%", mqttField: "temp", precisionVal: 2, sortOrder: 0, edgeDeviceId: 3, description: "使用中", createdAt: "2024-10-10 10:27:18", updatedAt: nil, isActive: true),
        SensorRow(code: "dht22_3", name: "实验用 1", sensorTypeCode: "dht22", unit: "°C/%", mqttField: "temp", precisionVal: 2, sortOrder: 0, edgeDeviceId: nil, description: "检测使用中", createdAt: "2025-10-10 10:27:18", updatedAt: nil, isActive: true),
        SensorRow(code: "dht22_4", name: "待命名", sensorTypeCode: "dht22", unit: "°C/%", mqttField: "temp", precisionVal: 2, sortOrder: 0, edgeDeviceId: nil, description: "未使用", createdAt: "2026-01-20 11:00:18", updatedAt: nil, isActive: false),
        SensorRow(code: "dht22_5", name: "待命名", sensorTypeCode: "dht22", unit: "°C/%", mqttField: "temp", precisionVal: 2, sortOrder: 0, edgeDeviceId: nil, description: "未使用", createdAt: "2026-01-20 11:00:18", updatedAt: nil, isActive: false),
        SensorRow(code: "dht22_6", name: "未记录", sensorTypeCode: "dht22", unit: "°C/%", mqttField: "temp", precisionVal: 2, sortOrder: 0, edgeDeviceId: nil, description: nil, createdAt: nil, updatedAt: nil, isActive: true),
        SensorRow(code: "sht30_1", name: "客厅环境 1 号位", sensorTypeCode: "sht30", unit: "°C/%", mqttField: "temp", precisionVal: 2, sortOrder: 0, edgeDeviceId: 4, description: "使用中", createdAt: "2026-01-20 11:00:18", updatedAt: nil, isActive: true),
        SensorRow(code: "sht30_2", name: "实验用 1", sensorTypeCode: "sht30", unit: "°C / %", mqttField: "temp", precisionVal: 2, sortOrder: 1, edgeDeviceId: 3, description: "使用中", createdAt: "2026-04-19 13:32:00", updatedAt: nil, isActive: true),
        SensorRow(code: "sht30_3", name: "未记录", sensorTypeCode: "sht30", unit: "°C/%", mqttField: "temp", precisionVal: 2, sortOrder: 0, edgeDeviceId: nil, description: nil, createdAt: nil, updatedAt: nil, isActive: false),

        // 温湿度（新增）
        SensorRow(code: "shtc3_1", name: "主卧温湿度 SHTC3", sensorTypeCode: "shtc3", unit: "°C/%", mqttField: "temp", precisionVal: 2, sortOrder: 2, edgeDeviceId: 3, description: "低功耗温湿度采集", createdAt: "2026-04-20 00:00:00", updatedAt: nil, isActive: true),

        // 光照（新增）
        SensorRow(code: "bh1750_1", name: "客厅光照 BH1750", sensorTypeCode: "bh1750", unit: "lux", mqttField: "illuminance", precisionVal: 1, sortOrder: 3, edgeDeviceId: 4, description: "环境光照强度", createdAt: "2026-04-20 00:00:00", updatedAt: nil, isActive: true),
        SensorRow(code: "tsl2591_1", name: "阳台光照 TSL2591", sensorTypeCode: "tsl2591", unit: "lux", mqttField: "illuminance", precisionVal: 1, sortOrder: 4, edgeDeviceId: nil, description: "高动态范围光照", createdAt: "2026-04-20 00:00:00", updatedAt: nil, isActive: true),

        // 空气质量（新增）
        SensorRow(code: "pms7003_1", name: "客厅 PM2.5 PMS7003", sensorTypeCode: "pms7003", unit: "ug/m3", mqttField: "pm25", precisionVal: 1, sortOrder: 5, edgeDeviceId: 4, description: "空气颗粒物监测", createdAt: "2026-04-20 00:00:00", updatedAt: nil, isActive: true),
        SensorRow(code: "ccs811_1", name: "客厅空气质量 CCS811", sensorTypeCode: "ccs811", unit: "ppm/ppb", mqttField: "co2", precisionVal: 1, sortOrder: 6, edgeDeviceId: 4, description: "eCO2 与 TVOC 监测", createdAt: "2026-04-20 00:00:00", updatedAt: nil, isActive: true),

        SensorRow(code: "hc_sr501_1", name: "客厅微型人体红外感应模块PIR", sensorTypeCode: "hc_sr501", unit: "", mqttField: "human", precisionVal: 0, sortOrder: 0, edgeDeviceId: nil, description: "使用中-感应客厅是否有人", createdAt: nil, updatedAt: nil, isActive: true),
        
        SensorRow(code: "raspberry_pi_camera", name: "RaspberryPi 摄像头", sensorTypeCode: "raspberry_pi_camera_module3_unknown_brand", unit: "", mqttField: "camera", precisionVal: 0, sortOrder: 0, edgeDeviceId: nil, description: "使用中-客厅感应识别并录像", createdAt: nil, updatedAt: nil, isActive: true),
    ]

    private static var seededSensorCodes: [String] { sensorRows.map(\.code) }

    func prepare(on database: Database) async throws {
        for row in Self.sensorRows {
            if try await Sensor.query(on: database).filter(\.$code == row.code).first() != nil {
                continue
            }
            var eDevId: Int?
            if let edgeDeviceId = row.edgeDeviceId,
               let edev = try await EdgeDevice.query(on: database).filter(\.$id == edgeDeviceId).first(),
               let id = edev.id
            {
                eDevId = id
            }

            guard let st = try await SensorType.query(on: database).filter(\.$code == row.sensorTypeCode).first(),
                  let typeId = st.id
            else {
                throw SeedSensorsError.missingSensorType(code: row.sensorTypeCode)
            }

            let s = Sensor()
            s.name = row.name
            s.code = row.code
            s.$sensorType.id = typeId
            s.unit = row.unit
            s.mqttField = row.mqttField
            s.precisionVal = row.precisionVal
            s.sortOrder = row.sortOrder
            s.edgeDeviceId = eDevId
            s.sensorDescription = row.description
            s.createdAt = Self.parseStamp(row.createdAt)
            s.updatedAt = Self.parseStamp(row.updatedAt)
            s.isActive = row.isActive
            try await s.save(on: database)
        }
    }

    func revert(on database: Database) async throws {
        for code in Self.seededSensorCodes {
            try await Sensor.query(on: database).filter(\.$code == code).delete()
        }
    }

    private enum SeedSensorsError: Error, CustomStringConvertible {
        case missingSensorType(code: String)

        var description: String {
            switch self {
            case .missingSensorType(let c): return "SeedSensors: no sensor_type with code=\(c)"
            }
        }
    }
}
