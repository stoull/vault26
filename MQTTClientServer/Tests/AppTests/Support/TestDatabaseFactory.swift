import Foundation
import XCTest
import SQLKit
@testable import App

enum TestDatabaseFactory {
    private static let testDatabaseNameKey = "TEST_DB_DATABASE"
    private static let testDatabaseModeKey = "TEST_DB_MODE"
    private static let testAdminDatabaseKey = "TEST_DB_ADMIN_DATABASE"

    private enum TestDatabaseMode: String {
        case fixed
        case isolated
    }

    private static func makeDatabaseConfig(databaseName: String) -> DatabaseConfig {
        let env = ProcessInfo.processInfo.environment
        let host = env["TEST_DB_HOST"] ?? env["DB_HOST"] ?? "127.0.0.1"
        let port = Int(env["TEST_DB_PORT"] ?? "") ?? Int(env["DB_PORT"] ?? "") ?? 3306
        let user = env["TEST_DB_USERNAME"] ?? env["DB_USERNAME"] ?? "root"
        let password = env["TEST_DB_PASSWORD"] ?? env["DB_PASSWORD"] ?? ""

        return DatabaseConfig(
            host: host,
            port: port,
            user: user,
            password: password,
            name: databaseName,
            maxConnectionsPerEventLoop: 2,
            connectionPoolTimeout: .seconds(10),
            pruneInterval: .seconds(30),
            maxIdleTimeBeforePruning: .seconds(30)
        )
    }

    static func withIsolatedDatabase(
        testName: String = #function,
        _ body: (DatabaseManager) async throws -> Void
    ) async throws {
        let env = ProcessInfo.processInfo.environment
        guard let databaseName = env[testDatabaseNameKey], !databaseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw XCTSkip("Integration test skipped: set TEST_DB_DATABASE.")
        }

        let modeRaw = env[testDatabaseModeKey]?.lowercased() ?? TestDatabaseMode.fixed.rawValue
        let mode = TestDatabaseMode(rawValue: modeRaw) ?? .fixed

        switch mode {
        case .fixed:
            let manager = DatabaseManager(config: makeDatabaseConfig(databaseName: databaseName))
            defer { Task { await manager.shutdown() } }
            _ = testName // keep parameter to preserve call-site readability
            do {
                try await prepareSchemaAndSeeds(manager)
            } catch {
                let errorText = "\(error)".lowercased()
                if errorText.contains("unknown database") {
                    throw XCTSkip("Integration test skipped: fixed test database '\(databaseName)' does not exist.")
                }
                if errorText.contains("access denied") {
                    throw XCTSkip("Integration test skipped: no permission on fixed test database '\(databaseName)'.")
                }
                throw error
            }
            try await resetMutableTables(on: manager)
            try await body(manager)

        case .isolated:
            let adminDatabaseName = env[testAdminDatabaseKey] ?? "mysql"
            let tempDatabaseName = makeIsolatedDatabaseName(base: databaseName, testName: testName)

            let adminManager = DatabaseManager(config: makeDatabaseConfig(databaseName: adminDatabaseName))
            defer { Task { await adminManager.shutdown() } }
            try await adminManager.waitUntilReady(maxAttempts: 5, delay: .seconds(1))
            try await createDatabase(named: tempDatabaseName, on: adminManager)
            defer {
                Task {
                    try? await dropDatabase(named: tempDatabaseName, on: adminManager)
                }
            }

            let manager = DatabaseManager(config: makeDatabaseConfig(databaseName: tempDatabaseName))
            defer { Task { await manager.shutdown() } }
            try await prepareSchemaAndSeeds(manager)
            try await resetMutableTables(on: manager)
            try await body(manager)
        }
    }

    static func prepareSchemaAndSeeds(_ dbManager: DatabaseManager) async throws {
        try await dbManager.waitUntilReady(maxAttempts: 5, delay: .seconds(1))
        try await dbManager.runMigrations([
            CreateLocation(),
            SeedLocation(),
            CreateDeviceType(),
            SeedDeviceTypes(),
            CreateEdgeDevice(),
            SeedEdgeDevices(),
            CreateSensorType(),
            SeedSensorTypes(),
            CreateSensor(),
            SeedSensors(),
            CreateEnvironmentReadings(),
            CreateEdgeDeviceMetric()
        ])
    }

    static func clearEdgeDeviceMetrics(on dbManager: DatabaseManager) async throws {
        try await EdgeDeviceMetric.query(on: dbManager.db()).delete()
    }

    private static func resetMutableTables(on dbManager: DatabaseManager) async throws {
        try await clearEdgeDeviceMetrics(on: dbManager)
        try await EnvironmentReadings.query(on: dbManager.db()).delete()
    }

    private static func createDatabase(named name: String, on dbManager: DatabaseManager) async throws {
        guard let sqlDB = dbManager.db() as? any SQLDatabase else { return }
        try await sqlDB
            .raw("CREATE DATABASE IF NOT EXISTS `\(unsafeRaw: name)` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
            .run()
    }

    private static func dropDatabase(named name: String, on dbManager: DatabaseManager) async throws {
        guard let sqlDB = dbManager.db() as? any SQLDatabase else { return }
        try await sqlDB
            .raw("DROP DATABASE IF EXISTS `\(unsafeRaw: name)`")
            .run()
    }

    private static func makeIsolatedDatabaseName(base: String, testName: String) -> String {
        let baseSanitized = sanitizeIdentifier(base)
        let testSanitized = sanitizeIdentifier(testName)
        let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased().prefix(8)
        let maxBaseLength = max(1, 64 - (1 + testSanitized.count + 1 + suffix.count))
        return "\(String(baseSanitized.prefix(maxBaseLength)))_\(testSanitized)_\(suffix)"
    }

    private static func sanitizeIdentifier(_ raw: String) -> String {
        let value = raw.lowercased().map { ch -> Character in
            (ch.isLetter || ch.isNumber || ch == "_") ? ch : "_"
        }
        var cleaned = String(value).trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        if cleaned.isEmpty { cleaned = "testdb" }
        if let first = cleaned.first, first.isNumber { cleaned = "t_\(cleaned)" }
        return cleaned
    }
}
