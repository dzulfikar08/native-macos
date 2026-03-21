import XCTest
import CoreMedia
import CoreGraphics
@testable import OpenScreen

/// Tests for TestDataFactory transition helper methods
final class TestDataFactoryTests: XCTestCase {

    // MARK: - Basic Transition Helpers

    func testMakeTransitionWithDefaults() {
        let transition = TestDataFactory.makeTransition()

        XCTAssertEqual(transition.type, .crossfade)
        XCTAssertEqual(transition.duration.seconds, 1.0, accuracy: 0.01)
        XCTAssertTrue(transition.isEnabled)
        XCTAssertTrue(transition.isValid)
    }

    func testMakeTransitionWithCustomParameters() {
        let leadingID = UUID()
        let trailingID = UUID()
        let duration = CMTime(seconds: 2.0, preferredTimescale: 600)

        let transition = TestDataFactory.makeTransition(
            type: .wipe,
            duration: duration,
            leadingClipID: leadingID,
            trailingClipID: trailingID,
            isEnabled: false
        )

        XCTAssertEqual(transition.type, .wipe)
        XCTAssertEqual(transition.duration.seconds, 2.0, accuracy: 0.01)
        XCTAssertEqual(transition.leadingClipID, leadingID)
        XCTAssertEqual(transition.trailingClipID, trailingID)
        XCTAssertFalse(transition.isEnabled)
    }

    // MARK: - Type-Specific Transition Helpers

    func testMakeCrossfadeTransition() {
        let duration = CMTime(seconds: 1.5, preferredTimescale: 600)
        let transition = TestDataFactory.makeCrossfadeTransition(duration: duration)

        XCTAssertEqual(transition.type, .crossfade)
        XCTAssertEqual(transition.duration.seconds, 1.5, accuracy: 0.01)
        XCTAssertTrue(transition.isValid)
    }

    func testMakeFadeToColorTransition() {
        let transition = TestDataFactory.makeFadeToColorTransition(
            color: .white,
            holdDuration: 1.0
        )

        XCTAssertEqual(transition.type, .fadeToColor)
        XCTAssertTrue(transition.isValid)

        // Verify parameters
        if case .fadeToColor(let color, let holdDuration) = transition.parameters {
            XCTAssertEqual(color, .white)
            XCTAssertEqual(holdDuration, 1.0)
        } else {
            XCTFail("Expected fadeToColor parameters")
        }
    }

    func testMakeWipeTransition() {
        let transition = TestDataFactory.makeWipeTransition(
            direction: .right,
            softness: 0.5,
            borderWidth: 2.0
        )

        XCTAssertEqual(transition.type, .wipe)
        XCTAssertTrue(transition.isValid)

        // Verify parameters
        if case .wipe(let direction, let softness, let borderWidth) = transition.parameters {
            XCTAssertEqual(direction, .right)
            XCTAssertEqual(softness, 0.5, accuracy: 0.01)
            XCTAssertEqual(borderWidth, 2.0, accuracy: 0.01)
        } else {
            XCTFail("Expected wipe parameters")
        }
    }

    func testMakeIrisTransition() {
        let position = CGPoint(x: 0.3, y: 0.7)
        let transition = TestDataFactory.makeIrisTransition(
            shape: .square,
            position: position,
            softness: 0.4
        )

        XCTAssertEqual(transition.type, .iris)
        XCTAssertTrue(transition.isValid)

        // Verify parameters
        if case .iris(let shape, let pos, let softness) = transition.parameters {
            XCTAssertEqual(shape, .square)
            XCTAssertEqual(pos.x, 0.3, accuracy: 0.01)
            XCTAssertEqual(pos.y, 0.7, accuracy: 0.01)
            XCTAssertEqual(softness, 0.4, accuracy: 0.01)
        } else {
            XCTFail("Expected iris parameters")
        }
    }

    func testMakeBlindsTransition() {
        let transition = TestDataFactory.makeBlindsTransition(
            orientation: .horizontal,
            slatCount: 15
        )

        XCTAssertEqual(transition.type, .blinds)
        XCTAssertTrue(transition.isValid)

        // Verify parameters
        if case .blinds(let orientation, let slatCount) = transition.parameters {
            XCTAssertEqual(orientation, .horizontal)
            XCTAssertEqual(slatCount, 15)
        } else {
            XCTFail("Expected blinds parameters")
        }
    }

    // MARK: - Edge Case Helpers

    func testMakeTransitionWithInvalidDuration() {
        let transition = TestDataFactory.makeTransitionWithInvalidDuration()

        XCTAssertEqual(transition.type, .crossfade)
        XCTAssertEqual(transition.duration.seconds, 10.0, accuracy: 0.01)
        // Note: Duration itself is valid (> 0), but may be too long for practical use
        XCTAssertTrue(transition.isValid)
    }

    func testMakeTransitionWithMinimumDuration() {
        let transition = TestDataFactory.makeTransitionWithMinimumDuration()

        XCTAssertEqual(transition.type, .crossfade)
        XCTAssertEqual(transition.duration.seconds, 0.1, accuracy: 0.01)
        XCTAssertTrue(transition.isValid)
    }

    func testMakeTransitionWithCustomParameters() {
        let transition = TestDataFactory.makeTransitionWithCustomParameters()

        if case .custom(let name) = transition.type {
            XCTAssertEqual(name, "myCustomTransition")
        } else {
            XCTFail("Expected custom transition type")
        }

        XCTAssertTrue(transition.isValid)

        // Verify parameters
        if case .custom(let params) = transition.parameters {
            XCTAssertEqual(params["param1"], 1.0, accuracy: 0.01)
            XCTAssertEqual(params["param2"], 2.0, accuracy: 0.01)
        } else {
            XCTFail("Expected custom parameters")
        }
    }

    func testMakeCustomTransitionWithParameters() {
        let transition = TestDataFactory.makeTransitionWithCustomParameters()

        if case .custom(let name) = transition.type {
            XCTAssertEqual(name, "myCustomTransition")
        } else {
            XCTFail("Expected custom transition type")
        }

        XCTAssertTrue(transition.isValid)

        // Verify parameters
        if case .custom(let params) = transition.parameters {
            XCTAssertNotNil(params["param1"])
            XCTAssertNotNil(params["param2"])
        } else {
            XCTFail("Expected custom parameters")
        }
    }

    // MARK: - VideoClip + Transition Helpers

    func testMakeOverlappingClipsWithTransition() {
        let (leadingClip, trailingClip, transition) = TestDataFactory.makeOverlappingClipsWithTransition()

        // Verify leading clip timing
        XCTAssertEqual(leadingClip.timeRangeInTimeline.start.seconds, 0.0, accuracy: 0.01)
        XCTAssertEqual(leadingClip.timeRangeInTimeline.duration.seconds, 5.0, accuracy: 0.01)

        // Verify trailing clip timing
        XCTAssertEqual(trailingClip.timeRangeInTimeline.start.seconds, 3.0, accuracy: 0.01)
        XCTAssertEqual(trailingClip.timeRangeInTimeline.duration.seconds, 5.0, accuracy: 0.01)

        // Verify transition references correct clips
        XCTAssertEqual(transition.leadingClipID, leadingClip.id)
        XCTAssertEqual(transition.trailingClipID, trailingClip.id)
        XCTAssertEqual(transition.duration.seconds, 1.0, accuracy: 0.01)

        // Calculate overlap
        let leadingEnd = leadingClip.timeRangeInTimeline.end.seconds
        let trailingStart = trailingClip.timeRangeInTimeline.start.seconds
        let overlapDuration = leadingEnd - trailingStart

        // Should have 2 seconds of overlap (leading ends at 5s, trailing starts at 3s)
        XCTAssertEqual(overlapDuration, 2.0, accuracy: 0.01)

        // Transition should fit within the overlap
        XCTAssertLessThanOrEqual(transition.duration.seconds, overlapDuration)
    }

    func testMakeNonOverlappingClipsWithTransition() {
        let (leadingClip, trailingClip, transition) = TestDataFactory.makeNonOverlappingClipsWithTransition()

        // Verify leading clip timing
        XCTAssertEqual(leadingClip.timeRangeInTimeline.start.seconds, 0.0, accuracy: 0.01)
        XCTAssertEqual(leadingClip.timeRangeInTimeline.duration.seconds, 3.0, accuracy: 0.01)

        // Verify trailing clip timing
        XCTAssertEqual(trailingClip.timeRangeInTimeline.start.seconds, 4.0, accuracy: 0.01)
        XCTAssertEqual(trailingClip.timeRangeInTimeline.duration.seconds, 3.0, accuracy: 0.01)

        // Verify transition references correct clips
        XCTAssertEqual(transition.leadingClipID, leadingClip.id)
        XCTAssertEqual(transition.trailingClipID, trailingClip.id)

        // Calculate overlap
        let leadingEnd = leadingClip.timeRangeInTimeline.end.seconds
        let trailingStart = trailingClip.timeRangeInTimeline.start.seconds

        // Should have NO overlap (leading ends at 3s, trailing starts at 4s)
        XCTAssertLessThan(leadingEnd, trailingStart)

        // Transition should NOT fit within the overlap (gap exists)
        let gap = trailingStart - leadingEnd
        XCTAssertGreaterThan(gap, 0)

        // This represents an invalid configuration
        // The transition duration exceeds the available overlap (which is negative)
        let overlapDuration = leadingEnd - trailingStart
        XCTAssertGreaterThan(transition.duration.seconds, overlapDuration)
    }

    // MARK: - Legacy Helpers (for backward compatibility)

    func testLegacyMakeTestTransition() {
        let transition = TestDataFactory.makeTestTransition()

        XCTAssertEqual(transition.type, .crossfade)
        XCTAssertEqual(transition.duration.seconds, 1.0, accuracy: 0.01)
        XCTAssertTrue(transition.isEnabled)
        XCTAssertTrue(transition.isValid)
    }

    func testLegacyMakeTestCrossfade() {
        let transition = TestDataFactory.makeTestCrossfade(duration: 2.0)

        XCTAssertEqual(transition.type, .crossfade)
        XCTAssertEqual(transition.duration.seconds, 2.0, accuracy: 0.01)
    }

    func testLegacyMakeTestWipe() {
        let transition = TestDataFactory.makeTestWipe(direction: .up)

        XCTAssertEqual(transition.type, .wipe)
        if case .wipe(let direction, _, _) = transition.parameters {
            XCTAssertEqual(direction, .up)
        } else {
            XCTFail("Expected wipe parameters")
        }
    }

    func testLegacyMakeTestIris() {
        let transition = TestDataFactory.makeTestIris(shape: .star)

        XCTAssertEqual(transition.type, .iris)
        if case .iris(let shape, _, _) = transition.parameters {
            XCTAssertEqual(shape, .star)
        } else {
            XCTFail("Expected iris parameters")
        }
    }
}
