import XCTest
import CoreGraphics
@testable import OpenScreen

final class TransitionParametersTests: XCTestCase {
    // MARK: - Crossfade Parameters Tests

    func testCrossfadeParameters() {
        let params = TransitionParameters.crossfade
        XCTAssertTrue(params.isValid)
    }

    // MARK: - Fade to Color Tests

    func testFadeToBlackParameters() {
        let params = TransitionParameters.fadeToColor(color: .black, holdDuration: 0.5)
        XCTAssertTrue(params.isValid)
    }

    func testFadeToColorWithInvalidHoldDuration() {
        let params = TransitionParameters.fadeToColor(color: .black, holdDuration: 10.0)
        XCTAssertFalse(params.isValid, "Hold duration should not exceed 5 seconds")
    }

    func testFadeToColorWithInvalidColor() {
        let invalidColor = TransitionColor(red: 2.0, green: 0, blue: 0, alpha: 1)
        let params = TransitionParameters.fadeToColor(color: invalidColor, holdDuration: 0.5)
        XCTAssertFalse(params.isValid, "Color values must be in [0, 1]")
    }

    // MARK: - Wipe Parameters Tests

    func testWipeParameters() {
        let params = TransitionParameters.wipe(direction: .left, softness: 0.5, borderWidth: 2.0)
        XCTAssertTrue(params.isValid)
    }

    func testWipeWithInvalidSoftness() {
        let params = TransitionParameters.wipe(direction: .left, softness: 1.5, borderWidth: 0)
        XCTAssertFalse(params.isValid, "Softness must be in [0, 1]")
    }

    func testWipeWithInvalidBorderWidth() {
        let params = TransitionParameters.wipe(direction: .left, softness: 0, borderWidth: 25.0)
        XCTAssertFalse(params.isValid, "Border width must not exceed 20")
    }

    // MARK: - Iris Parameters Tests

    func testIrisParameters() {
        let params = TransitionParameters.iris(
            shape: .circle,
            position: CGPoint(x: 0.5, y: 0.5),
            softness: 0.3
        )
        XCTAssertTrue(params.isValid)
    }

    func testIrisWithInvalidPosition() {
        let params = TransitionParameters.iris(
            shape: .circle,
            position: CGPoint(x: 1.5, y: 0.5),
            softness: 0.3
        )
        XCTAssertFalse(params.isValid, "Position must be normalized to [0, 1]")
    }

    // MARK: - Blinds Parameters Tests

    func testBlindsParameters() {
        let params = TransitionParameters.blinds(orientation: .vertical, slatCount: 10)
        XCTAssertTrue(params.isValid)
    }

    func testBlindsWithInvalidSlatCount() {
        let params = TransitionParameters.blinds(orientation: .vertical, slatCount: 100)
        XCTAssertFalse(params.isValid, "Slat count must be between 2 and 50")
    }

    func testBlindsWithMinimumSlatCount() {
        let params = TransitionParameters.blinds(orientation: .horizontal, slatCount: 2)
        XCTAssertTrue(params.isValid, "Minimum slat count should be 2")
    }

    // MARK: - Custom Parameters Tests

    func testCustomParameters() {
        let params = TransitionParameters.custom(parameters: ["speed": 1.0, "angle": 45.0])
        XCTAssertTrue(params.isValid)
    }

    func testCustomParametersWithNaN() {
        let params = TransitionParameters.custom(parameters: ["speed": Double.nan])
        XCTAssertFalse(params.isValid, "NaN values should be invalid")
    }

    // MARK: - Default Parameters Tests

    func testDefaultParametersForTypes() {
        let crossfadeDefault = TransitionParameters.default(for: .crossfade)
        if case .crossfade = crossfadeDefault {
            // Success
        } else {
            XCTFail("Default parameters for crossfade should be .crossfade")
        }

        let wipeDefault = TransitionParameters.default(for: .wipe)
        if case .wipe = wipeDefault {
            // Success
        } else {
            XCTFail("Default parameters for wipe should be .wipe")
        }
    }

    // MARK: - Codable Tests

    func testParametersEncodingDecoding() {
        let original = TransitionParameters.wipe(direction: .diagonalLeft, softness: 0.5, borderWidth: 1.0)
        let encoded = try? JSONEncoder().encode(original)
        let decoded = try? JSONDecoder().decode(TransitionParameters.self, from: encoded!)

        XCTAssertEqual(decoded, original)
    }

    func testColorEncodingDecoding() {
        let original = TransitionColor(red: 0.5, green: 0.3, blue: 0.8, alpha: 1.0)
        let encoded = try? JSONEncoder().encode(original)
        let decoded = try? JSONDecoder().decode(TransitionColor.self, from: encoded!)

        XCTAssertEqual(decoded, original)
    }
}
