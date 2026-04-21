//
//  config.swift
//  MQTTClientServer
//
//  Created by Hut on 2026/4/11.
//

import Foundation
import Logging

enum config {
    // MariaDB 配置
    // static let DB_HOST = ProcessInfo.processInfo.environment["DB_HOST"] ?? "macmini.local"
    
    // 优先使用EnvLoader中的变量值
    static let DB_HOST =        EnvLoader.shared.DB_HOST ?? env("DB_HOST",      "macmini.local")
    static let DB_PORT =        EnvLoader.shared.DB_PORT ?? envInt("DB_PORT",   3306)
    static let DB_USERNAME =    EnvLoader.shared.DB_USERNAME ?? env("DB_USERNAME",  "username")
    static let DB_PASSWORD =    EnvLoader.shared.DB_PASSWORD ?? env("DB_PASSWORD",  "user_password")
    static let DB_DATABASE =    EnvLoader.shared.DB_DATABASE ?? env("DB_DATABASE",  "home_db")
    
    // MQTT 配置
    static let MQTT_HOST =      EnvLoader.shared.MQTT_HOST ?? env("MQTT_HOST",    "macmini.local")
    static let MQTT_PORT =      EnvLoader.shared.MQTT_PORT ?? envInt("MQTT_PORT", 1883)
    static let MQTT_USERNAME =  EnvLoader.shared.MQTT_USERNAME ?? env("MQTT_USERNAME", "username")
    static let MQTT_PASSWORD =  EnvLoader.shared.MQTT_PASSWORD ?? env("MQTT_PASSWORD", "user_password")
    
    // 其它配置
    static let mqttClientId = "swift-mqtt-client-\(UUID().uuidString)"
    // 支持多个主题，用逗号分隔，例如: "test/data,sensor/temperature,device/status"
    /**
     传感器数据主题结构:
     sensor/env/dht20/+/data
     sensor/env/dht22/+/data
     sensor/env/sht30/+/data
     sensor/env/sht35/+/data
     
     sensor/env/dht22/001/temperature
     sensor/motion/mpu6050/001/acceleration
     sensor/gas/mq135/001/co2
     */
    static let mqttTopics: [String] =
    {
        let topicsString = "home/+/+/+/metrics,home/+/env/+/status,home/+/env/+/state,sensor/env/+/+/data,test/updates,sensor/dht22/+/data,device/system/+/device_info,note/+/home"
        return topicsString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }()
    static let mqttSystemTopics: [String] =
    {
        /**
        开发/运维诊断：订阅 $SYS/#（你现在就是这样）
        生产环境更克制：只订阅你真正要用的几条，减少流量与 ACL 风险
        $SYS/broker/clients/connected：当前连接客户端数
        $SYS/broker/clients/total：累计客户端数（有的版本不一定有）
        $SYS/broker/messages/received：Broker 收到的消息数
        $SYS/broker/messages/sent：Broker 发出的消息数
        $SYS/broker/uptime：Broker 运行时长
        $SYS/broker/load/messages/received/1min：负载类指标（不同版本路径可能不同）
        */
        let topicsString = "$SYS/#"
        return topicsString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }()
    static let mqttEnableTSL = false
    static let mqttKeepAliveInterval = Int64(60)
    
    // 打印配置（用于调试，注意不要打印敏感信息）
    static func printConfiguration() {
        
        let logger = Logger(label: "Configuration")
        
        logger.info("=== 配置信息 ===")
        logger.info("MQTT Broker: \(MQTT_HOST):\(MQTT_PORT)")
        logger.info("MQTT Username: \(MQTT_USERNAME.isEmpty ? "(未设置)" : "***")")
        logger.info("MQTT Password: \(MQTT_PASSWORD.isEmpty ? "(未设置)" : "***")")
        logger.info("MQTT Use SSL: \(mqttEnableTSL)")
        logger.info("MQTT Topics: \(mqttTopics.joined(separator: ", "))")
        logger.info("MQTT Client ID: \(mqttClientId)")
        logger.info("Database: \(DB_USERNAME)@\(DB_HOST):\(DB_PORT)/\(DB_DATABASE)")
        logger.info("================")
    }
}


// MARK: - 环境变量工具

private func env(_ key: String, _ fallback: String) -> String {
    ProcessInfo.processInfo.environment[key] ?? fallback
}
private func envInt(_ key: String, _ fallback: Int) -> Int {
    Int(ProcessInfo.processInfo.environment[key] ?? "") ?? fallback
}
private func envInt64(_ key: String, _ fallback: Int64) -> Int64 {
    Int64(ProcessInfo.processInfo.environment[key] ?? "") ?? fallback
}
