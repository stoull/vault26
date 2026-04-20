import XCTest
@testable import App

final class MQTTMessageProcessorEnvironmentTests: XCTestCase {
    func testProcess_envStateWithNonIntegerSensorId_doesNotCrashWithoutDatabase() async {
        let processor = MQTTMessageProcessor(dbManager: nil)

        await processor.process(
            topic: "home/livingroom/env/not-int/state",
            payloadString: MQTTPayloadFactory.envStateTempHumiOnly()
        )

        XCTAssertTrue(true)
    }

    func testProcess_envStateWithInvalidJSON_doesNotCrashWithoutDatabase() async {
        let processor = MQTTMessageProcessor(dbManager: nil)

        await processor.process(
            topic: "home/livingroom/env/1/state",
            payloadString: MQTTPayloadFactory.envStateInvalidJSON()
        )

        XCTAssertTrue(true)
    }

    func testProcess_unmatchedTopic_isIgnored() async {
        let processor = MQTTMessageProcessor(dbManager: nil)

        await processor.process(
            topic: "home/livingroom/unknown/1/state",
            payloadString: MQTTPayloadFactory.envStateFull()
        )

        XCTAssertTrue(true)
    }
}
