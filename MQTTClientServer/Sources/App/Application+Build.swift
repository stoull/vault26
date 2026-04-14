//
//  Application+Build.swift
//  MQTTClientServer
//
//  Created by Hut on 2026/4/10.
//

import Foundation
import Hummingbird
import Fluent
import NIOPosix
import Logging
import FluentMySQLDriver

// Keep a strong reference to DatabaseManager for the lifetime of the application
// so that its `Databases`/connection pool isn't deinitialized before shutdown.
fileprivate var sharedDatabaseManager: DatabaseManager?
fileprivate var sharedMqttService: MQTTService?

func buildApplication() async throws -> some ApplicationProtocol {
    let logger = Logger(label: "App")

    // 1. 初始化 DatabaseManager（连接池在此创建）
    let dbManager = DatabaseManager(config: .fromEnvironment())
    // retain for app lifetime
    sharedDatabaseManager = dbManager
    
    // 2. 等待 MariaDB 就绪（解决 Docker 启动时序问题）
    try await dbManager.waitUntilReady(maxAttempts: 5, delay: .seconds(3))

    // 2b. DB 可连后再开 keep-alive，避免与 waitUntilReady 并发握手失败导致 MariaDB 告警
    dbManager.startKeepAlive()

    // 3. 运行迁移（自动建表，已存在则跳过）
    try await dbManager.runMigrations([
        CreateSensorDHT22(),
        CreateSensorData()
    ])

    // 4. 启动 MQTT 服务
    let mqttService = try MQTTService(dbManager: dbManager)
    sharedMqttService = mqttService
    try await mqttService.start()

    // 5. 配置 Hummingbird 路由
    let router = Router()
     MQTTCommandRoutes(mqttService: mqttService).addRoutes(to: router)

    StatusRoutes().addRoutes(to: router)
    
    let app = Application(
        router: router,
        configuration: .init(address: .hostname("0.0.0.0", port: 8080))
    )

    logger.info("Application started on :8080")
    return app
}

// Shutdown helper to be called by the application exit path
func shutdownSharedDatabaseManager() async {
    if let db = sharedDatabaseManager {
        await db.shutdown()
        sharedDatabaseManager = nil
    }
}
