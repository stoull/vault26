// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "MQTTClientServer",
    platforms: [.macOS(.v14)],
    dependencies: [
        // 声明要哪些外部包，拉哪个仓库、什么版本,下载源码包到本地，并构建
        // Hummingbird 2 web framework
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        // MQTT NIO client
        .package(url: "https://github.com/adam-fowler/mqtt-nio.git", from: "2.11.0"),
        // Fluent ORM
        .package(url: "https://github.com/vapor/fluent.git", from: "4.9.0"),
        // MySQL/MariaDB driver
        .package(url: "https://github.com/vapor/fluent-mysql-driver.git", from: "4.4.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.14.0"),
        .package(url: "https://github.com/vapor/sql-kit.git", from: "3.28.0")
    ],
    targets: [
        .executableTarget(
            name: "App", // 所有属于这个可执行程序的 Swift 文件应在 Sources/App/ 下，因为SwiftPM 的默认规则是：target 名决定默认的 Sources/<name>/ 根 Sources/<TargetName>/ → Sources/App/
            dependencies: [
                // 声明这个 target 要链接其中哪个 Package 构建好的 product
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdTLS", package: "hummingbird"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
                .product(name: "MQTTNIO", package: "mqtt-nio"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentMySQLDriver", package: "fluent-mysql-driver"),
                .product(name: "SQLKit", package: "sql-kit"),
                .product(name: "NIOPosix", package: "swift-nio")
            ],
            exclude: ["./Migrations/FluentMigrationReadMe.md", "./Departured"],// 排除文件
            resources: [
                .process("config.json"),
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "AppTests",
            dependencies: [
                .target(name: "App"),
            ]
        ),
    ]
)
