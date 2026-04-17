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
    
    // 检查环境变量
    _ = try await EnvLoader.shared.loadEnv()

    // 1. 初始化 DatabaseManager（连接池在此创建）
    let dbManager = DatabaseManager(config: .fromEnvironment())
    // retain for app lifetime
    sharedDatabaseManager = dbManager
    
    // 2. 等待 MariaDB 就绪（解决 Docker 启动时序问题）
    try await dbManager.waitUntilReady(maxAttempts: 5, delay: .seconds(3))

    /**
     默认每 30 秒执行一次 SELECT 1
     若你没有遇到 MariaDB 大量 Aborted connection、或空闲期连接被中间设备掐掉等问题，可以删，减少一个长期后台任务和日志。
     若你确实遇到过启动阶段告警或长时间几乎无 DB 访问时的连接问题，保留更合理。
     */
    // dbManager.startKeepAlive()

    // 3. 运行迁移（自动建表，已存在则跳过）
    try await dbManager.runMigrations([
        CreateSensorDataTempHumi(),
        CreateSystemDevices(),
        CreateSystemDeviceSnapshots()
        // AddSensorTypeToSensorDataTempHumi()
    ])

    // 4. 启动 MQTT 服务
    let mqttService = try MQTTService(dbManager: dbManager)
    sharedMqttService = mqttService
    try await mqttService.start()

    // 5. 配置 Hummingbird 路由
    let router = Router()
    router.middlewares.add(APILanguageMiddleware())
    router.middlewares.add(FileMiddleware()) // 默认从当前工作目录下的 public 提供文件
     MQTTCommandRoutes(mqttService: mqttService).addRoutes(to: router)

    StatusRoutes().addRoutes(to: router)
    SystemDeviceRoutes(dbManager: dbManager).addRoutes(to: router)
    
    let app = Application(
        router: router,
        configuration: .init(address: .hostname("0.0.0.0", port: 8044))
    )

    logger.info("Application started on :8044")
    return app
}

// Shutdown helper to be called by the application exit path
func shutdownSharedDatabaseManager() async {
    if let db = sharedDatabaseManager {
        await db.shutdown()
        sharedDatabaseManager = nil
    }
}
