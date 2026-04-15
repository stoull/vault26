//
//  DatabaseManager.swift
//  MQTTClientServer
//
//  Created by Hut on 2026/4/10.
//

import Fluent
import FluentMySQLDriver
import NIOCore
import SQLKit
import Logging
import Foundation

// MARK: - 配置结构

struct DatabaseConfig {
    let host:     String
    let port:     Int
    let user:     String
    let password: String
    let name:     String

    // 连接池配置
    let maxConnectionsPerEventLoop: Int     // 每个 EventLoop 最大连接数
    let connectionPoolTimeout:      TimeAmount  // 等待可用连接的超时时间
    let pruneInterval:              TimeAmount  // 多久检查一次空闲连接
    let maxIdleTimeBeforePruning:   TimeAmount  // 连接空闲多久后被回收

    static func fromEnvironment() -> DatabaseConfig {
        DatabaseConfig(
            host:     config.DB_HOST,
            port:     config.DB_PORT,
            user:     config.DB_USERNAME,
            password: config.DB_PASSWORD,
            name:     config.DB_DATABASE,
            maxConnectionsPerEventLoop: 4,
            connectionPoolTimeout:      .seconds(30),
            pruneInterval:              .seconds(60),
            maxIdleTimeBeforePruning:   .seconds(120)
        )
    }
}

// MARK: - DatabaseManager

final class DatabaseManager: Sendable {
    let databases: Databases
    private let logger: Logger
    private let config: DatabaseConfig

    // Keep-alive task to retain a lightweight periodic ping so the connection pool
    // doesn't open and immediately close sockets. This helps avoid "Aborted connection"
    // caused by very short-lived client sockets.
    // Swift 6: `Sendable` class cannot have mutable stored properties; this handle is only
    // set from `startKeepAlive` and cleared in `shutdown`, which the app runs sequentially.
    nonisolated(unsafe) private var keepAliveTask: Task<Void, Never>?

    init(config: DatabaseConfig) {
        self.config  = config
        self.logger  = Logger(label: "DatabaseManager")
        self.databases = Databases(
            threadPool: .singleton,
            on: .singletonMultiThreadedEventLoopGroup
        )
        setupPool()
        // Keep-alive is started explicitly after `waitUntilReady()` so we do not
        // race with startup polling; concurrent failed handshakes while MariaDB
        // is still booting otherwise trigger server-side "Aborted connection"
        // warnings (Got an error reading communication packets).
    }

    /// 取得默认 MySQL 数据库实例
    func db() -> Database {
        databases.database(
            .mysql,
            logger: logger,
            on: .singletonMultiThreadedEventLoopGroup.any()
        )!
    }

    /// 关闭所有连接（graceful shutdown 时调用）
    func shutdown() async {
        // Cancel keep-alive task first so it won't attempt further queries
        if let t = keepAliveTask {
            logger.info("Cancelling DB keep-alive task")
            t.cancel()
            // do not forcibly await value; just nil it out to break strong refs
            keepAliveTask = nil
        }
        await databases.shutdownAsync()
        logger.info("DatabaseManager: all connections closed")
    }

    // MARK: - Private

    private func setupPool() {
        let factory = DatabaseConfigurationFactory.mysql(
            hostname:                   config.host,
            port:                       config.port,
            username:                   config.user,
            password:                   config.password,
            database:                   config.name,
            tlsConfiguration:           nil,
            maxConnectionsPerEventLoop: config.maxConnectionsPerEventLoop,
            connectionPoolTimeout:      config.connectionPoolTimeout,
            pruneInterval:              config.pruneInterval,      // 定期清理空闲连接
            maxIdleTimeBeforePruning:   config.maxIdleTimeBeforePruning  // 空闲超时自动回收
        )
        databases.use(factory, as: .mysql)
        logger.info("""
            DB pool configured: \(config.host):\(config.port)/\(config.name) \
            maxConn=\(config.maxConnectionsPerEventLoop) \
            idleTimeout=\(config.maxIdleTimeBeforePruning.nanoseconds / 1_000_000_000)s
            """)
    }

    /**
     默认每 30 秒执行一次 SELECT 1
     若你没有遇到 MariaDB 大量 Aborted connection、或空闲期连接被中间设备掐掉等问题，可以删，减少一个长期后台任务和日志。
     若你确实遇到过启动阶段告警或长时间几乎无 DB 访问时的连接问题，保留更合理。
     */
    /// Start a background task that periodically runs a cheap `SELECT 1` to keep at least
    /// one connection active and ensure the pool doesn't open then immediately close sockets.
    /// Call once the database accepts connections (e.g. after `waitUntilReady()`).
    func startKeepAlive(interval: Duration = .seconds(30)) {
        // Cancel any existing task
        keepAliveTask?.cancel()

        keepAliveTask = Task { [weak self] in
            guard let self = self else { return }
            self.logger.info("DB keep-alive started (interval: \(interval))")
            while !Task.isCancelled {
                do {
                    if let sqlDB = self.db() as? any SQLDatabase {
                        try await sqlDB.raw("SELECT 1").run()
                        self.logger.debug("DB keep-alive ping succeeded")
                    } else {
                        self.logger.debug("DB not SQL-capable; skipping keep-alive ping")
                    }
                } catch {
                    self.logger.warning("DB keep-alive ping failed: \(error)")
                }
                // Sleep until next ping or cancellation
                do {
                    try await Task.sleep(for: interval)
                } catch {
                    // Task.sleep throws on cancellation - break out cleanly
                    break
                }
            }
            self.logger.info("DB keep-alive stopped")
        }
    }
}

// MARK: - 启动时等待 DB 就绪

extension DatabaseManager {
    /// 轮询直到 MariaDB 可以接受连接（适用于 Docker 启动时序问题）
    func waitUntilReady(
        maxAttempts: Int = 15,
        delay: Duration = .seconds(3)
    ) async throws {
        logger.info("Waiting for database to be ready...")
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                guard let sqlDB = db() as? any SQLDatabase else {
                    throw DBError.queryFailed("Database does not support SQLDatabase protocol")
                }
                try await sqlDB.raw("SELECT 1").run() // sqlDB.raw 原始 SQL 字符串    执行任意 SQL
                logger.info("Database is ready (attempt \(attempt))")
                return
            } catch {
                lastError = error
                logger.warning("DB not ready [\(attempt)/\(maxAttempts)]: \(error)")
                try await Task.sleep(for: delay)
            }
        }
        throw DBError.connectionFailed(lastError!)
    }
}

// MARK: - 迁移

extension DatabaseManager {
    func runMigrations(_ migrations: [any Migration]) async throws {
        let migrationSet = Migrations()
        migrations.forEach { migrationSet.add($0) }

        let migrator = Migrator(
            databases:  databases,
            migrations: migrationSet,
            logger:     logger,
            on:         .singletonMultiThreadedEventLoopGroup.any()
        )

        // Diagnostic: preview which migrations would be prepared so we can see if our migrations
        // are being discovered/registered by the Migrator.
//        do {
//            let preview = try await migrator.previewPrepareBatch().asAsync()
//            let names = preview.map { pair -> String in
//                let mig = pair.0
//                let dbid = pair.1
//                return "\(mig.name)@\(dbid?.string ?? "default")"
//            }
//            logger.info("Migrations preview (to be applied): \(names.joined(separator: ", "))")
//        } catch {
//            logger.warning("Failed to preview migrations: \(error)")
//        }

        do {
            try await migrator.setupIfNeeded().asAsync()
            try await migrator.prepareBatch().asAsync()
            logger.info("Migrations completed")
        } catch {
            logger.error("Migrations failed: \(String(reflecting: error))")
            throw error
        }
    }
}

// MARK: - 带重试的操作封装

extension DatabaseManager {
    /// 执行数据库操作，失败时自动重试
    /// - Parameters:
    ///   - maxAttempts: 最大尝试次数（默认 3）
    ///   - delay: 每次重试间隔（默认 2s）
    ///   - operation: 要执行的数据库操作
    func withRetry<T>(
        maxAttempts: Int = 3,
        delay: Duration = .seconds(2),
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                // 只有可重试的错误才重试（连接类错误），业务错误直接抛出
                guard error.isRetryable else { throw error }
                logger.warning("DB retry [\(attempt)/\(maxAttempts)]: \(error)")
                if attempt < maxAttempts {
                    try await Task.sleep(for: delay)
                }
            }
        }
        throw lastError!
    }
}

// MARK: - 错误定义

enum DBError: Error, LocalizedError {
    case connectionFailed(Error)
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let e): return "DB connection failed: \(e)"
        case .queryFailed(let msg):    return "DB query failed: \(msg)"
        }
    }
}

// MARK: - Error 扩展：判断是否可重试

private extension Error {
    /// 连接断开、超时类错误可以重试；约束违反等业务错误不重试
    var isRetryable: Bool {
        let desc = "\(self)".lowercased()
        return desc.contains("connection")
            || desc.contains("timeout")
            || desc.contains("lost")
            || desc.contains("broken pipe")
    }
}

// Helper: bridge EventLoopFuture -> async/await
import NIOCore

extension EventLoopFuture {
    /// Bridge an `EventLoopFuture` into async/await world.
    /// Usage: `try await someFuture.asAsync()`
    func asAsync() async throws -> Value {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Value, Error>) in
            self.whenComplete { result in
                switch result {
                case .success(let value): continuation.resume(returning: value)
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
    }
}
