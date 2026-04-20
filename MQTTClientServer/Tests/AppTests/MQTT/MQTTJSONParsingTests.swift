import XCTest
@testable import App

final class MQTTJSONParsingTests: XCTestCase {
    func testPayloadFactory_envStateFull_isValidJSON() throws {
        let payload = MQTTPayloadFactory.envStateFull()
        let data = try XCTUnwrap(payload.data(using: .utf8))
        let obj = try JSONSerialization.jsonObject(with: data)
        XCTAssertNotNil(obj as? [String: Any])
    }

    func testPayloadFactory_envStateInvalidJSON_isInvalidJSON() {
        let payload = MQTTPayloadFactory.envStateInvalidJSON()
        let data = payload.data(using: .utf8) ?? Data()
        XCTAssertThrowsError(try JSONSerialization.jsonObject(with: data))
    }
}
