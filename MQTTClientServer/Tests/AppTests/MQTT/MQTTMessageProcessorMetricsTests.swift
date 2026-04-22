import XCTest
@testable import App

final class MQTTMessageProcessorMetricsTests: XCTestCase {
    func testProcess_metrics_writesEdgeDeviceMetric_withValidPayload() async throws {
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
                topic: "home/livingroom/env/esp32_D777EC/metrics",
                payloadString: MQTTPayloadFactory.metricsMinimalValid()
            )

            let rows = try await EdgeDeviceMetric.query(on: dbManager.db())
                .filter(\.$device.$id, .equal, deviceId)
                .all()

            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows.first?.createdAtISO, "2026-04-20T10:30:00+08:00")
            XCTAssertEqual(rows.first?.resetReason, 0)
        }
    }
}
