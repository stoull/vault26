//
//  SensorDataTempHumiRenameTable.swift
//  MQTTClientServer
//
//  Created by Hut on 2026/4/16.
//

import Foundation
import Fluent

// 将旧表 sensor_dht22 重命名为 sensor_data_temp_humi
//struct SensorDataTempHumiRenameTable: AsyncMigration {
//    var name: String { "SensorDataTempHumiRenameTable" }
//
//    func prepare(on database: Database) async throws {
//        try await database.schema("sensor_dht22")
//            .rename(to: "sensor_data_temp_humi")
//            .update()
//    }
//
//    func revert(on database: Database) async throws {
//        try await database.schema("sensor_data_temp_humi")
//            .rename(to: "sensor_dht22")
//            .update()
//    }
//}
