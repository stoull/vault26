import XCTest
@testable import App

final class MQTTMessageProcessorErrorTests: XCTestCase {
    func testProcess_metrics_missingUniqueId_doesNotPersist() async throws {
        try await TestDatabaseFactory.withIsolatedDatabase { dbManager in
            guard let device = try await EdgeDevice.query(on: dbManager.db())
                .filter(\.$uniqueId, .equal, "ACA704D777EC")
                .first(),
                  let deviceId = device.id
            else {
                XCTFail("Seeded edge device not found")
                return
            }

            let processor = MQTTMessageProcessor(dbManager: dbManager)
            await processor.process(
                topic: "home/livingroom/env/\(deviceId)/metrics",
                payloadString: MQTTPayloadFactory.metricsMissingUniqueId()
            )

            let rows = try await EdgeDeviceMetric.query(on: dbManager.db())
                .filter(\.$device.$id, .equal, deviceId)
                .all()

            XCTAssertEqual(rows.count, 0)
        }
    }
}
