import XCTest
@testable import OpenScreen

final class TransitionTypeTests: XCTestCase {
    // MARK: - Initialization Tests

    func testCrossfadeType() {
        let type = TransitionType.crossfade
        XCTAssertEqual(type.rawValue, "crossfade")
        XCTAssertEqual(type.displayName, "Crossfade")
        XCTAssertEqual(type.category, .basic)
    }

    func testFadeToColorType() {
        let type = TransitionType.fadeToColor
        XCTAssertEqual(type.rawValue, "fadeToColor")
        XCTAssertEqual(type.displayName, "Fade to Color")
        XCTAssertEqual(type.category, .basic)
    }

    func testWipeType() {
        let type = TransitionType.wipe
        XCTAssertEqual(type.rawValue, "wipe")
        XCTAssertEqual(type.displayName, "Wipe")
        XCTAssertEqual(type.category, .directional)
    }

    func testIrisType() {
        let type = TransitionType.iris
        XCTAssertEqual(type.rawValue, "iris")
        XCTAssertEqual(type.displayName, "Iris")
        XCTAssertEqual(type.category, .shape)
    }

    func testBlindsType() {
        let type = TransitionType.blinds
        XCTAssertEqual(type.rawValue, "blinds")
        XCTAssertEqual(type.displayName, "Blinds")
        XCTAssertEqual(type.category, .directional)
    }

    func testCustomType() {
        let type = TransitionType.custom("My Transition")
        XCTAssertEqual(type.rawValue, "custom:My Transition")
        XCTAssertEqual(type.displayName, "My Transition")
        XCTAssertEqual(type.category, .custom)
    }

    // MARK: - Default Duration Tests

    func testDefaultDurations() {
        XCTAssertEqual(TransitionType.crossfade.defaultDuration, 1.0)
        XCTAssertEqual(TransitionType.fadeToColor.defaultDuration, 1.5)
        XCTAssertEqual(TransitionType.wipe.defaultDuration, 1.0)
        XCTAssertEqual(TransitionType.iris.defaultDuration, 1.5)
        XCTAssertEqual(TransitionType.blinds.defaultDuration, 1.0)
    }

    // MARK: - Codable Tests

    func testEncodingDecoding() throws {
        let original = TransitionType.crossfade
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TransitionType.self, from: encoded)
        XCTAssertEqual(decoded, original)
    }

    func testCustomTypeEncodingDecoding() throws {
        let original = TransitionType.custom("Custom Transition")
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TransitionType.self, from: encoded)
        XCTAssertEqual(decoded, original)
    }
}
