import XCTest
import CoreMedia
@testable import OpenScreen

final class TransitionClipTests: XCTestCase {
    // MARK: - Initialization Tests

    func testTransitionClipInitialization() {
        let duration = CMTime(seconds: 1.0, preferredTimescale: 600)
        let leadingID = UUID()
        let trailingID = UUID()
        let params = TransitionParameters.crossfade

        let transition = TransitionClip(
            id: UUID(),
            type: .crossfade,
            duration: duration,
            leadingClipID: leadingID,
            trailingClipID: trailingID,
            parameters: params
        )

        XCTAssertEqual(transition.type, .crossfade)
        XCTAssertEqual(transition.duration, duration)
        XCTAssertEqual(transition.leadingClipID, leadingID)
        XCTAssertEqual(transition.trailingClipID, trailingID)
        XCTAssertEqual(transition.parameters, .crossfade)
        XCTAssertTrue(transition.isEnabled)
    }

    func testTransitionClipWithDefaultParameters() {
        let duration = CMTime(seconds: 1.5, preferredTimescale: 600)
        let transition = TransitionClip(
            type: .iris,
            duration: duration,
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )

        XCTAssertEqual(transition.type, .iris)
        if case .iris = transition.parameters {
            // Success
        } else {
            XCTFail("Should have default iris parameters")
        }
    }

    func testTransitionClipWithDisabledState() {
        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID(),
            isEnabled: false
        )

        XCTAssertFalse(transition.isEnabled)
    }

    // MARK: - Validation Tests

    func testValidTransition() {
        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )

        XCTAssertTrue(transition.isValid)
    }

    func testInvalidTransitionWithNegativeDuration() {
        let duration = CMTime(seconds: -1.0, preferredTimescale: 600)
        let transition = TransitionClip(
            type: .crossfade,
            duration: duration,
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )

        XCTAssertFalse(transition.isValid)
    }

    func testInvalidTransitionWithInvalidParameters() {
        var transition = TransitionClip(
            type: .wipe,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )

        // Set invalid parameters
        transition.parameters = .wipe(direction: .left, softness: 2.0, borderWidth: 0)

        XCTAssertFalse(transition.isValid)
    }

    // MARK: - Convenience Methods Tests

    func testDurationInSeconds() {
        let duration = CMTime(seconds: 2.5, preferredTimescale: 600)
        let transition = TransitionClip(
            type: .crossfade,
            duration: duration,
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )

        XCTAssertEqual(transition.durationInSeconds, 2.5, accuracy: 0.01)
    }

    func testWithType() {
        let original = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )

        let modified = original.withType(.wipe)

        XCTAssertEqual(modified.type, .wipe)
        XCTAssertEqual(modified.leadingClipID, original.leadingClipID)
        XCTAssertEqual(modified.trailingClipID, original.trailingClipID)
    }

    func testWithDuration() {
        let original = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )

        let newDuration = CMTime(seconds: 2.0, preferredTimescale: 600)
        let modified = original.withDuration(newDuration)

        XCTAssertEqual(modified.duration, newDuration)
    }

    func testWithParameters() {
        let original = TransitionClip(
            type: .wipe,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )

        let newParams = TransitionParameters.wipe(direction: .right, softness: 0.5, borderWidth: 1.0)
        let modified = original.withParameters(newParams)

        XCTAssertEqual(modified.parameters, newParams)
    }

    func testToggled() {
        let enabled = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID(),
            isEnabled: true
        )

        let disabled = enabled.toggled()

        XCTAssertFalse(disabled.isEnabled)
    }

    // MARK: - Codable Tests

    func testEncodingDecoding() {
        let original = TransitionClip(
            type: .iris,
            duration: CMTime(seconds: 1.5, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )

        let encoded = try? JSONEncoder().encode(original)
        let decoded = try? JSONDecoder().decode(TransitionClip.self, from: encoded!)

        XCTAssertEqual(decoded, original)
    }

    // MARK: - Equatable Tests

    func testEquality() {
        let id = UUID()
        let duration = CMTime(seconds: 1.0, preferredTimescale: 600)
        let leadingID = UUID()
        let trailingID = UUID()

        let transition1 = TransitionClip(
            id: id,
            type: .crossfade,
            duration: duration,
            leadingClipID: leadingID,
            trailingClipID: trailingID
        )

        let transition2 = TransitionClip(
            id: id,
            type: .crossfade,
            duration: duration,
            leadingClipID: leadingID,
            trailingClipID: trailingID
        )

        XCTAssertEqual(transition1, transition2)
    }

    func testInequality() {
        let duration = CMTime(seconds: 1.0, preferredTimescale: 600)

        let transition1 = TransitionClip(
            type: .crossfade,
            duration: duration,
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )

        let transition2 = TransitionClip(
            type: .wipe,
            duration: duration,
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )

        XCTAssertNotEqual(transition1, transition2)
    }
}
