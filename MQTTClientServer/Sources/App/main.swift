import Hummingbird
import Logging

let logger = Logger(label: "MQTTClientServer")

let app = try await buildApplication()
try await app.runService()

// Ensure database connections are closed cleanly before process exit
await shutdownSharedDatabaseManager()
