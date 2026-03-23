import XCTest
import CoreMedia
@testable import OpenScreen

final class TransitionValidatorEdgeCasesTests: XCTestCase {

    func testZeroDurationTransition() {
        let validator = TransitionValidator()

        let result = validator.validate(
            type: .crossfade,
            duration: .zero,
            overlap: CMTime(seconds: 1, preferredTimescale: 600)
        )

        XCTAssertFalse(result.isValid)
    }

    func testNegativeDurationTransition() {
        let validator = TransitionValidator()

        let result = validator.validate(
            type: .crossfade,
            duration: CMTime(seconds: -1, preferredTimescale: 600),
            overlap: CMTime(seconds: 1, preferredTimescale: 600)
        )

        XCTAssertFalse(result.isValid)
    }

    func testNoOverlapTransition() {
        let validator = TransitionValidator()

        let result = validator.validate(
            type: .wipe,
            duration: CMTime(seconds: 1, preferredTimescale: 600),
            overlap: .zero
        )

        XCTAssertFalse(result.isValid)
    }

    func testOverlapLongerThanDuration() {
        let validator = TransitionValidator()

        let result = validator.validate(
            type: .iris,
            duration: CMTime(seconds: 1, preferredTimescale: 600),
            overlap: CMTime(seconds: 2, preferredTimescale: 600)
        )

        // Should either warn or adjust overlap
        XCTAssertTrue(result.isValid || result.warnings.count > 0)
    }

    func testTransitionWithVerySmallOverlap() {
        let validator = TransitionValidator()

        let result = validator.validate(
            type: .crossfade,
            duration: CMTime(seconds: 1, preferredTimescale: 600),
            overlap: CMTime(seconds: 0.01, preferredTimescale: 600) // 10ms
        )

        XCTAssertFalse(result.isValid)
    }

    func testExtremeParameterValues() {
        let validator = TransitionValidator()

        // Test wipe with extreme softness
        let transition1 = TransitionClip(
            type: .wipe,
            duration: CMTime(seconds: 1, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID(),
            parameters: .wipe(direction: .left, softness: 5.0, border: -100),
            isEnabled: true
        )

        let result1 = validator.validate(clip: transition1)
        // Should handle gracefully, either clamp or warn
        XCTAssertTrue(result1.isValid || result1.warnings.count > 0)
    }
}
