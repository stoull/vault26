import XCTest
@testable import App

final class MQTTTopicPatternTests: XCTestCase {
    func testMatchesPlusWildcard() {
        let topic = "home/livingroom/env/1/state"
        let pattern = "home/+/env/+/state"

        XCTAssertTrue(MQTTTopicPattern.matchesMQTTPattern(topic: topic, pattern: pattern))
    }

    func testExtractsWildcardSegments() {
        let topic = "home/livingroom/env/1/state"
        let pattern = "home/+/env/+/state"

        XCTAssertEqual(
            MQTTTopicPattern.extractFromTopic(topic, pattern: pattern, wildcardIndex: 0),
            "livingroom"
        )
        XCTAssertEqual(
            MQTTTopicPattern.extractFromTopic(topic, pattern: pattern, wildcardIndex: 1),
            "1"
        )
    }

    func testDoesNotMatchDifferentLevelCount() {
        let topic = "home/livingroom/env/1/state/extra"
        let pattern = "home/+/env/+/state"

        XCTAssertFalse(MQTTTopicPattern.matchesMQTTPattern(topic: topic, pattern: pattern))
    }
}
