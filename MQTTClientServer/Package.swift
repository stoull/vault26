// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "MQTTClientServer",
    platforms: [.macOS(.v14)],
    dependencies: [
        // Hummingbird 2 web framework
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        // MQTT NIO client
        .package(url: "https://github.com/adam-fowler/mqtt-nio.git", from: "2.11.0"),
        // Fluent ORM
        .package(url: "https://github.com/vapor/fluent.git", from: "4.9.0"),
        // MySQL/MariaDB driver
        .package(url: "https://github.com/vapor/fluent-mysql-driver.git", from: "4.4.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
        .package(url: "https://github.com/vapor/sql-kit.git", from: "3.28.0"),
        
        // SwiftyJSON 改使用手动引入
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", from: "4.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "MQTTNIO", package: "mqtt-nio"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentMySQLDriver", package: "fluent-mysql-driver"),
                .product(name: "SQLKit", package: "sql-kit"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "SwiftyJSON", package: "SwiftyJSON"),
            ],
            resources: [
                .process("config.json")
            ]
        ),
    ]
)
