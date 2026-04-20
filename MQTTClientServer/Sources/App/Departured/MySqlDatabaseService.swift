//
//  File.swift
//  MQTTClientServer
//
//  Created by Hut on 2026/4/11.
//

import Foundation
import MySQLNIO
import NIO
import Logging
import SwiftyJSON

/**
    直接使用 MySQLNIO 连接 MariaDB 的示例，已不用
    直接使用 MySQLNIO 连接 MariaDB，提供更底层的数据库操作接口。
    MySqlDatabaseService 负责管理与 MariaDB 的连接，并提供保存 MQTT 消息的接口。
 */
class MySqlDatabaseService {
    private let logger = Logger(label: "com.mqttserver.database")
    private let eventLoopGroup: EventLoopGroup
    private var connection: MySQLConnection?
    private var healthCheckTask: RepeatedTask?
    private var isReconnecting = false
    
    // 重连配置
    private let initialReconnectDelay: TimeAmount = .seconds(1)
    private let maxReconnectDelay: TimeAmount = .seconds(30)
    private let maxReconnectAttempts = 10
    private let healthCheckInterval: TimeAmount = .seconds(30)
    private let healthCheckInitialDelay: TimeAmount = .seconds(10)
    
    init(eventLoopGroup: EventLoopGroup) throws {
        self.eventLoopGroup = eventLoopGroup
    }
    
    func connect() -> EventLoopFuture<Void> {
        return establishConnection()
    }
    
    /// 建立数据库连接
    private func establishConnection() -> EventLoopFuture<Void> {
        let eventLoop = eventLoopGroup.next()
        
        let address: SocketAddress
        do {
            address = try SocketAddress.makeAddressResolvingHost(
                config.DB_HOST,
                port: config.DB_PORT
            )
        } catch {
            return eventLoop.makeFailedFuture(error)
        }
        
        return MySQLConnection.connect(
            to: address,
            username: config.DB_USERNAME,
            database: config.DB_DATABASE,
            password: config.DB_PASSWORD,
            tlsConfiguration: nil,
            on: eventLoop
        ).map { connection in
            self.connection = connection
            self.logger.info("已连接到 MariaDB 数据库")
            self.isReconnecting = false
            // 连接成功后启动健康检查
            self.startHealthCheck()
        }.flatMapError { error in
            self.logger.error("数据库连接失败: \(error)")
            return eventLoop.makeFailedFuture(error)
        }
    }
    
    /// 启动定期健康检查
    private func startHealthCheck() {
        // 取消现有的健康检查任务
        self.healthCheckTask?.cancel()
        
        let eventLoop = eventLoopGroup.next()
        // 定期执行健康检查：初始延迟10秒，之后每30秒执行一次
        self.healthCheckTask = eventLoop.scheduleRepeatedTask(
            initialDelay: healthCheckInitialDelay,
            delay: healthCheckInterval
        ) { task in
            guard let conn = self.connection else {
                self.logger.warning("健康检查：无数据库连接，触发重连")
                self.triggerReconnect()
                return
            }
            
            // 执行轻量级查询检查连接状态
            conn.simpleQuery("SELECT 1").whenFailure { error in
                self.logger.warning("健康检查失败: \(error)，将尝试重连")
                self.triggerReconnect()
            }
        }
    }
    
    /// 触发重连机制
    private func triggerReconnect() {
        let eventLoop = eventLoopGroup.next()
        eventLoop.execute {
            // 确保只有一个重连循环在运行
            if self.isReconnecting {
                return
            }
            self.isReconnecting = true
            self.attemptReconnect(attempt: 1)
        }
    }
    
    /// 尝试重连（带指数退避）
    private func attemptReconnect(attempt: Int) {
        let eventLoop = eventLoopGroup.next()
        let delay = calculateBackoffDelay(for: attempt)
        
        self.logger.info("重连尝试 \(attempt)/\(maxReconnectAttempts)，将在 \(delay.nanoseconds / 1_000_000_000) 秒后重试")
        
        eventLoop.scheduleTask(deadline: .now() + delay) {
            self.establishConnection().whenComplete { result in
                switch result {
                case .success:
                    self.logger.info("重连成功（第 \(attempt) 次尝试）")
                case .failure(let error):
                    self.logger.error("重连失败（第 \(attempt) 次尝试）: \(error)")
                    if attempt < self.maxReconnectAttempts {
                        self.attemptReconnect(attempt: attempt + 1)
                    } else {
                        self.logger.error("达到最大重连次数 (\(self.maxReconnectAttempts))，将继续定期尝试")
                        // 达到最大次数后，使用最大延迟时间继续定期尝试
                        self.eventLoopGroup.next().scheduleTask(deadline: .now() + self.maxReconnectDelay) {
                            self.isReconnecting = false
                            self.triggerReconnect()
                        }
                    }
                }
            }
        }
    }
    
    /// 计算指数退避延迟时间
    private func calculateBackoffDelay(for attempt: Int) -> TimeAmount {
        // 指数退避：1s, 2s, 4s, 8s, 16s, 30s(最大)
        let multiplier = Double(1 << (max(0, attempt - 1)))
        let seconds = min(
            Double(initialReconnectDelay.nanoseconds) / 1_000_000_000.0 * multiplier,
            Double(maxReconnectDelay.nanoseconds) / 1_000_000_000.0
        )
        return .seconds(Int64(seconds))
    }
    
//    func initializeDatabase() -> EventLoopFuture<Void> {
//        guard let connection = connection else {
//            triggerReconnect()
//            return eventLoopGroup.next().makeFailedFuture(
//                DatabaseError.notConnected
//            )
//        }
//
//        let createTableSQL = """
//        CREATE TABLE IF NOT EXISTS mqtt_messages (
//            id INT AUTO_INCREMENT PRIMARY KEY,
//            topic VARCHAR(255) NOT NULL,
//            payload TEXT NOT NULL,
//            received_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
//            INDEX idx_topic (topic),
//            INDEX idx_received_at (received_at)
//        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
//        """
//
//        return connection.simpleQuery(createTableSQL).map { _ in
//            self.logger.info("数据库表初始化完成")
//        }.flatMapError { error in
//            self.logger.error("初始化数据库表失败: \(error)，触发重连")
//            self.triggerReconnect()
//            return self.eventLoopGroup.next().makeFailedFuture(error)
//        }
//    }
    
    func initializeDatabase(useTransaction: Bool = true) -> EventLoopFuture<Void> {
        guard let conn = connection else {
            return eventLoopGroup.next().makeFailedFuture(DatabaseError.notConnected)
        }

        let statements: [String] = [
            
            /**
             传感器数据
             sensor/dht22/1/data
             sensor/dht22/2/data
             sensor/dht22/10/data

             `specific`          : 0
             `livingroom`        : 1
             `fridge`            : 2
             `office`             : 10

             笔记
             note/0/home
             note/${user_id}/home/

             `notification`      : 0
             `user_id`           : user

             信息
             message/home

             `sensor/dht22/+/data`: 订阅所有的dht22传感器数据
             `note/+/home`: 订阅所有的hom笔记
             */
            
            // 示例表：mqtt_messages
            """
            CREATE TABLE IF NOT EXISTS mqtt_messages (
                id INT AUTO_INCREMENT PRIMARY KEY,
                topic VARCHAR(255) NOT NULL,
                payload TEXT NOT NULL,
                received_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX idx_topic (topic),
                INDEX idx_received_at (received_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """,
            
            // 示例表：sensor dht22
            """
            CREATE TABLE IF NOT EXISTS sensor_dht22 (
                id INT AUTO_INCREMENT PRIMARY KEY,
                sensor_id INT NOT NULL,
                temperature NUMERIC(5,2) NOT NULL,
                humidity NUMERIC(5,2) NOT NULL,
                created_at DATETIME NOT NULL,
                -- 存储 ISO 8601 原始字符串，例如:
                -- "2025-12-09T08:00:00Z" 或 "2025-12-09T08:00:00+08:00"
                created_at_iso CHAR(33) NOT NULL,
                -- 服务器接收时间（带毫秒精度）
                received_at DATETIME NOT NULL DEFAULT NOW()
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """,
            
            // 示例表：note
            """
            CREATE TABLE IF NOT EXISTS note (
                id INT AUTO_INCREMENT PRIMARY KEY,
                user_id INT NOT NULL,
                content TEXT NOT NULL, 
                created_at DATETIME NOT NULL DEFAULT NOW(),
                received_at DATETIME NOT NULL DEFAULT NOW()
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """
        ]

        // Helper: 顺序执行语句数组
        func runStatementsSequentially(_ stmts: [String]) -> EventLoopFuture<Void> {
            let initial: EventLoopFuture<Void> = eventLoopGroup.next().makeSucceededFuture(())
            return stmts.reduce(initial) { future, sql in
                future.flatMap { _ in
                    conn.simpleQuery(sql).map { _ in
                        self.logger.debug("执行 SQL 完成: \(sql.split(separator: "\\n").first ?? "")")
                    }
                }
            }
        }

        if useTransaction {
            // START TRANSACTION -> run statements -> COMMIT, 出错时 ROLLBACK
            return conn.simpleQuery("START TRANSACTION").flatMap { _ in
                runStatementsSequentially(statements)
            }.flatMap { _ in
                conn.simpleQuery("COMMIT").map { _ in
                    self.logger.info("数据库表创建事务提交成功")
                }
            }.flatMapError { err in
                self.logger.error("初始化表时出错，尝试回滚: \(err)")
                return conn.simpleQuery("ROLLBACK").flatMap { _ in
                    self.eventLoopGroup.next().makeFailedFuture(err)
                }.flatMapError { rbErr in
                    // 回滚也失败，返回原始错误和回滚错误信息
                    self.logger.error("回滚失败: \(rbErr)")
                    return self.eventLoopGroup.next().makeFailedFuture(err)
                }
            }
        } else {
            // 非事务逐条执行
            return runStatementsSequentially(statements).map {
                self.logger.info("数据库表逐条创建完成（非事务）")
            }
        }
    }
    
    func saveMessage(topic: String, payload: String) -> EventLoopFuture<Void> {
        guard let connection = connection else {
            triggerReconnect()
            return eventLoopGroup.next().makeFailedFuture(
                DatabaseError.notConnected
            )
        }
        
        // 匹配 sensor/dht22/+/data 模式
        // logger.info("匹配 sensor/dht22/+/data 模式 topic: \(topic)")
        if matchesMQTTPattern(topic: topic, pattern: "sensor/dht22/+/data") {
            return saveSensorDHT22Data(topic: topic, payload: payload, connection: connection)
        }
        // 匹配 device/system/+/device_info 模式
        else if matchesMQTTPattern(topic: topic, pattern: "device/system/+/device_info") {
            return saveSystemDeviceData(topic: topic, payload: payload, connection: connection)
        }
        // 匹配 note/+/home 模式
        else if matchesMQTTPattern(topic: topic, pattern: "note/+/home") {
            return saveNoteData(topic: topic, payload: payload, connection: connection)
        }
        // 默认保存到 mqtt_messages 表
        else {
            return saveToDefaultTable(topic: topic, payload: payload, connection: connection)
        }
    }
    
    /// 保存 DHT22 传感器数据
    private func saveSensorDHT22Data(topic: String, payload: String, connection: MySQLConnection) -> EventLoopFuture<Void> {
        // 从 topic 提取 sensor_id，例如 "sensor/dht22/1/data" -> "1"
        guard let sensorIdStr = extractFromTopic(topic, pattern: "sensor/dht22/+/data", wildcardIndex: 0),
              let sensorId = Int(sensorIdStr) else {
            logger.error("无法从主题 \(topic) 提取传感器ID")
            return saveToDefaultTable(topic: topic, payload: payload, connection: connection)
        }
        
        // 解析 JSON payload
        let json = JSON(parseJSON: payload)
        
        guard let jsonData = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let temperature = json["temperature"] as? Double,
              let humidity = json["humidity"] as? Double,
              let createdAtISO = json["created_at"] as? String else {
            logger.error("DHT22 数据格式错误: \(payload)")
            return saveToDefaultTable(topic: topic, payload: payload, connection: connection)
        }
        
        // 解析 ISO 8601 时间戳
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let createdAt = iso8601ToMySQLTimestampNoMillisToDate(createdAtISO)else {
            logger.error("无法解析时间戳: \(createdAtISO)")
            return saveToDefaultTable(topic: topic, payload: payload, connection: connection)
        }
        
        let insertSQL = """
        INSERT INTO sensor_dht22 (sensor_id, temperature, humidity, created_at, created_at_iso)
        VALUES (?, ?, ?, ?, ?)
        """
        
        return connection.query(insertSQL, [
            MySQLData(int: sensorId),
            MySQLData(double: temperature),
            MySQLData(double: humidity),
            MySQLData(date: createdAt),
            MySQLData(string: createdAtISO)
        ]).map { _ in
            self.logger.info("DHT22 传感器数据已保存: sensor_id=\(sensorId), temp=\(temperature)°C, humidity=\(humidity)%")
        }.flatMapError { error in
            self.logger.error("保存 DHT22 数据失败: \(error)")
            self.triggerReconnect()
            return self.eventLoopGroup.next().makeFailedFuture(error)
        }
    }
    
    /// 保存 device info
    private func saveSystemDeviceData(topic: String, payload: String, connection: MySQLConnection) -> EventLoopFuture<Void> {
        // 从 topic 提取 device_id，例如 "device/system/2/device_info" -> "2"
        guard let deviceIdStr = extractFromTopic(topic, pattern: "device/system/+/device_info", wildcardIndex: 0),
              let deviceId = Int(deviceIdStr) else {
            logger.error("无法从主题 \(topic) 提取设备ID")
            return saveToDefaultTable(topic: topic, payload: payload, connection: connection)
        }
        
        // 解析 JSON payload
        let json = JSON(parseJSON: payload)
        
        // 提取必需字段
        guard let createdAtISO = json["created_at"].string,
              let osVersion = json["unique_id"].string else {
            logger.error("设备信息数据缺少必需字段:  \(payload)")
            return saveToDefaultTable(topic: topic, payload: payload, connection: connection)
        }
        
        let platform = json["platform"].stringValue
        let cpuFrequencyMhz = json["cpu_frequency_mhz"].intValue
        let cpuTemperature = json["cpu_temperature"].doubleValue
        let totalStorageBytes = json["total_storage_bytes"].intValue
        let usedStorageBytes = json["used_storage_bytes"].intValue
        let freeStorageBytes = json["free_storage_bytes"].intValue
        let storageUsagePercent = json["storage_usage_percent"].doubleValue
        let totalMemoryBytes = json["total_memory_bytes"].intValue
        let usedMemoryBytes = json["used_memory_bytes"].intValue
        let freeMemoryBytes = json["free_memory_bytes"].intValue
        let memoryUsagePercent = json["memory_usage_percent"].doubleValue
        let uptimeSeconds = json["uptime_seconds"].intValue
        let resetReason = json["reset_reason"].intValue
        
        // 提取可选字段
        let uniqueId = json["unique_id"].stringValue
        let batteryLevelPercent = json["battery_level_percent"].doubleValue

        let ip = json["ip"].stringValue
        let mac = json["mac"].stringValue
        let subnet = json["subnet"].stringValue
        let dns = json["dns"].stringValue
        let gateway = json["gateway"].stringValue
        
        let rssi = json["rssi"].intValue
        
        // 构建 extra_data JSON（可以存储 unique_id 或其他额外信息）
        var extraData: [String: Any] = [:]
//        if let uniqueId = uniqueId {
//            extraData["unique_id"] = uniqueId
//        }
        
        // 确保总是生成有效的 JSON 字符串（即使是空对象）
        var extraDataString: String? = nil
        if !extraData.isEmpty {
            if let extraJsonData = try? JSONSerialization.data(withJSONObject: extraData),
               let extraJsonString = String(data: extraJsonData, encoding: .utf8) {
                extraDataString = extraJsonString
            }
        }
        
        // 使用当前时间作为 timestamp
        let timestamp = Date()
        
        let insertSQL = """
        INSERT INTO edge_device_metric (
            device_id, created_at_iso, timestamp, platform, os_version, 
            cpu_frequency_mhz, cpu_temperature, 
            total_storage_bytes, used_storage_bytes, free_storage_bytes, storage_usage_percent,
            total_memory_bytes, used_memory_bytes, free_memory_bytes, memory_usage_percent,
            uptime_seconds, reset_reason,
            battery_level_percent, ip, mac, subnet, dns, gateway, rssi, extra_data
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        return connection.query(insertSQL, [
            MySQLData(int: deviceId),
            MySQLData(string: createdAtISO),
            MySQLData(date: timestamp),
            MySQLData(string: platform),
            MySQLData(string: osVersion),
            MySQLData(int: cpuFrequencyMhz),
            MySQLData(double: cpuTemperature),
            MySQLData(int: totalStorageBytes),
            MySQLData(int: usedStorageBytes),
            MySQLData(int: freeStorageBytes),
            MySQLData(double: storageUsagePercent),
            MySQLData(int: totalMemoryBytes),
            MySQLData(int: usedMemoryBytes),
            MySQLData(int: freeMemoryBytes),
            MySQLData(double: memoryUsagePercent),
            MySQLData(int: uptimeSeconds),
            MySQLData(int: resetReason),
            MySQLData(double: batteryLevelPercent),
            MySQLData(string: ip),
            MySQLData(string: mac),
            MySQLData(string: subnet),
            MySQLData(string: dns),
            MySQLData(string: gateway),
            MySQLData(int: rssi),
            extraDataString != nil ? (try! MySQLData(json:  extraDataString!)) : MySQLData.null
        ]).map { _ in
            // self.logger.info("设备信息已保存: device_id=\(deviceId), platform=\(platform), cpu_temp=\(cpuTemperature)°C, memory_usage=\(memoryUsagePercent)%")
        }.flatMapError { error in
            self.logger.error("保存设备信息失败:  \(error)")
            self.triggerReconnect()
            return self.eventLoopGroup.next().makeFailedFuture(error)
        }
    }
    
    /// 保存笔记数据
    private func saveNoteData(topic: String, payload: String, connection: MySQLConnection) -> EventLoopFuture<Void> {
        // 从 topic 提取 user_id，例如 "note/123/home" -> "123" 或 "note/0/home" -> "0"
        guard let userIdStr = extractFromTopic(topic, pattern: "note/+/home", wildcardIndex: 0),
              let userId = Int(userIdStr) else {
            logger.error("无法从主题 \(topic) 提取用户ID")
            return saveToDefaultTable(topic: topic, payload: payload, connection: connection)
        }
        
        // 解析 JSON payload
        guard let jsonData = payload.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let content = json["content"] as? String else {
            logger.error("content 数据格式错误: \(payload)")
            return saveToDefaultTable(topic: topic, payload: payload, connection: connection)
        }
        
        let insertSQL = """
        INSERT INTO note (user_id, content) VALUES (?, ?)
        """
        
        return connection.query(insertSQL, [
            MySQLData(int: userId),
            MySQLData(string: content)
        ]).map { _ in
            self.logger.info("笔记已保存: user_id=\(userId), content_length=\(content.count)")
        }.flatMapError { error in
            self.logger.error("保存笔记失败: \(error)")
            self.triggerReconnect()
            return self.eventLoopGroup.next().makeFailedFuture(error)
        }
    }
    
    /// 保存到默认的 mqtt_messages 表
    private func saveToDefaultTable(topic: String, payload: String, connection: MySQLConnection) -> EventLoopFuture<Void> {
        let insertSQL = """
        INSERT INTO mqtt_messages (topic, payload) VALUES (?, ?)
        """
        
        return connection.query(insertSQL, [
            MySQLData(string: topic),
            MySQLData(string: payload)
        ]).map { _ in
            self.logger.debug("消息已插入默认表: topic=\(topic)")
        }.flatMapError { error in
            self.logger.error("插入消息失败: \(error)，触发重连")
            self.triggerReconnect()
            return self.eventLoopGroup.next().makeFailedFuture(error)
        }
    }
    
    // MARK: - MQTT Topic Matching Utilities
    
    /// 匹配 MQTT 主题模式，支持单层通配符 (+) 和多层通配符 (#)
    /// - Parameters:
    ///   - topic: 实际收到的主题，如 "sensor/dht22/1/data"
    ///   - pattern: 订阅模式，如 "sensor/dht22/+/data"
    /// - Returns: 是否匹配
    private func matchesMQTTPattern(topic: String, pattern: String) -> Bool {
        let topicLevels = topic.split(separator: "/").map(String.init)
        let patternLevels = pattern.split(separator: "/").map(String.init)
        
        // 处理多层通配符 #（只能在最后）
        if patternLevels.last == "#" {
            // 模式必须短于或等于主题
            if patternLevels.count - 1 > topicLevels.count {
                return false
            }
            // 检查 # 之前的所有层级
            for i in 0..<(patternLevels.count - 1) {
                if patternLevels[i] != "+" && patternLevels[i] != topicLevels[i] {
                    return false
                }
            }
            return true
        }
        
        // 不使用 # 时，层级数必须相同
        guard topicLevels.count == patternLevels.count else {
            return false
        }
        
        // 逐层匹配
        for (topicLevel, patternLevel) in zip(topicLevels, patternLevels) {
            if patternLevel != "+" && patternLevel != topicLevel {
                return false
            }
        }
        
        return true
    }
    
    /// 从主题中提取特定位置的值
    /// 例如: extractFromTopic("sensor/dht22/1/data", pattern: "sensor/dht22/+/data", wildcardIndex: 0) -> "1"
    private func extractFromTopic(_ topic: String, pattern: String, wildcardIndex: Int) -> String? {
        let topicLevels = topic.split(separator: "/").map(String.init)
        let patternLevels = pattern.split(separator: "/").map(String.init)
        
        guard topicLevels.count == patternLevels.count else {
            return nil
        }
        
        var wildcardCount = 0
        for (index, patternLevel) in patternLevels.enumerated() {
            if patternLevel == "+" {
                if wildcardCount == wildcardIndex {
                    return topicLevels[index]
                }
                wildcardCount += 1
            }
        }
        
        return nil
    }
    
    func close() -> EventLoopFuture<Void> {
        // 停止健康检查
        self.healthCheckTask?.cancel()
        self.healthCheckTask = nil
        
        guard let connection = connection else {
            return eventLoopGroup.next().makeSucceededVoidFuture()
        }
        
        self.connection = nil
        self.isReconnecting = false
        return connection.close()
    }
}

enum DatabaseError: Error {
    case notConnected
    case configError(String)
}

