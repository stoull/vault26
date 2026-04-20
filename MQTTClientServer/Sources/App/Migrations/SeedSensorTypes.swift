//
//  SeedSensorTypes.swift
//  MQTTClientServer
//
//  在 `sensor_type` 中写入与 MQTT JSON `type` 字段（小写）对应的字典行；依赖 `CreateSensorType`。
//

import Foundation
import Fluent

struct SeedSensorTypes: AsyncMigration {
    var name: String { "SeedSensorTypes" }

    /// 与 `MQTTMessageProcessor.saveSensorEnvData` 中 `switch sensorType.lowercased()` 分支一致；`mqtt_prefix` 与 `home/+/env/+/status` 对齐。
    private static let rows: [(name: String, code: String, mqttPrefix: String, description: String?)] = [
        // 温湿度
        ("DHT11", "dht11", "env", "入门级温湿度，精度一般"),
        ("DHT20", "dht20", "env", nil),
        ("DHT22", "dht22", "env", "AM2302 同族"),
        ("AM2302", "am2302", "env", "DHT22 单总线"),
        ("SHT30", "sht30", "env", "Sensirion SHT30"),
        ("SHT31", "sht31", "env", "Sensirion SHT31"),
        ("SHT35", "sht35", "env", "Sensirion SHT35"),
        ("AHT10", "aht10", "env", nil),
        ("AHT20", "aht20", "env", nil),
        ("AHT25", "aht25", "env", nil),
        ("SHT40", "sht40", "env", "Sensirion 新一代"),
        ("SHT41", "sht41", "env", nil),
        ("SHT45", "sht45", "env", nil),
        ("BME280", "bme280", "env", "温湿压"),
        ("BME680", "bme680", "env", "温湿压 + 气体"),
        ("HTU21D", "htu21d", "env", "TE Connectivity"),
        ("HTU31D", "htu31d", "env", nil),
        ("SHTC3", "shtc3", "env", "低功耗温湿度"),

        // 光照
        ("BH1750", "bh1750", "env", "数字光照强度传感器（lux）"),
        ("TSL2591", "tsl2591", "env", "高动态范围光照强度传感器"),

        // 空气质量
        ("PMS7003", "pms7003", "env", "激光粉尘传感器，支持 PM1.0/2.5/10"),
        ("SCD40", "scd40", "env", "CO2 传感器，含温湿度补偿"),
        ("CCS811", "ccs811", "env", "eCO2/TVOC 数字空气质量传感器"),

        ("HC-SR501", "hc_sr501", "human", "微型人体红外感应模块PIR,2~5米，角度小于120°"),
        
        ("Raspberry Pi Camera Module 3", "raspberry_pi_camera_module3_official", "camera", "The classic compact camera for Raspberry Pi with a 12MP sensor and autofocus"),
        ("Raspberry Pi Camera Module 3 未知品牌", "raspberry_pi_camera_module3_unknown_brand", "camera", "树莓派4代b 2代 3代B 摄像头 500W万 CSI视频接口 支持3代b+/4代B"),
        
        
    ]

    private static var seededCodes: [String] { rows.map(\.code) }

    func prepare(on database: Database) async throws {
        for row in Self.rows {
            if try await SensorType.query(on: database).filter(\.$code == row.code).first() != nil {
                continue
            }
            let model = SensorType()
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
            try await SensorType.query(on: database).filter(\.$code == code).delete()
        }
    }
}
