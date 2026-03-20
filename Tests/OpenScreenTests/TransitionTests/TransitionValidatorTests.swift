import XCTest
import CoreMedia
@testable import OpenScreen

final class TransitionValidatorTests: XCTestCase {
    var validator: TransitionValidator!
    var leadingClip: VideoClip!
    var trailingClip: VideoClip!

    override func setUp() async throws {
        try await super.setUp()
        validator = TransitionValidator()

        // Create overlapping clips
        // Leading clip: 0-5 seconds
        leadingClip = VideoClip(
            name: "Leading Clip",
            asset: TestDataFactory.makeTestAVAsset(duration: 5.0),
            timeRangeInSource: CMTimeRange(
                start: .zero,
                end: CMTime(seconds: 5.0, preferredTimescale: 600)
            ),
            timeRangeInTimeline: CMTimeRange(
                start: .zero,
                end: CMTime(seconds: 5.0, preferredTimescale: 600)
            ),
            trackID: UUID()
        )

        // Trailing clip: 4-9 seconds (1 second overlap)
        trailingClip = VideoClip(
            name: "Trailing Clip",
            asset: TestDataFactory.makeTestAVAsset(duration: 5.0),
            timeRangeInSource: CMTimeRange(
                start: .zero,
                end: CMTime(seconds: 5.0, preferredTimescale: 600)
            ),
            timeRangeInTimeline: CMTimeRange(
                start: CMTime(seconds: 4.0, preferredTimescale: 600),
                end: CMTime(seconds: 9.0, preferredTimescale: 600)
            ),
            trackID: UUID()
        )
    }

    // MARK: - Duration Validation Tests

    func testValidDurationWithinOverlap() {
        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 0.5, preferredTimescale: 600),
            leadingClipID: leadingClip.id,
            trailingClipID: trailingClip.id
        )

        let overlap = CMTime(seconds: 1.0, preferredTimescale: 600)

        XCTAssertNoThrow(try validator.validate(transition, availableOverlap: overlap))
    }

    func testDurationExceedsOverlap() {
        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.5, preferredTimescale: 600),
            leadingClipID: leadingClip.id,
            trailingClipID: trailingClip.id
        )

        let overlap = CMTime(seconds: 1.0, preferredTimescale: 600)

        XCTAssertThrowsError(try validator.validate(transition, availableOverlap: overlap)) { error in
            guard case TransitionError.durationExceedsOverlap = error else {
                XCTFail("Expected durationExceedsOverlap error")
                return
            }
        }
    }

    func testDurationBelowMinimum() {
        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 0.05, preferredTimescale: 600),
            leadingClipID: leadingClip.id,
            trailingClipID: trailingClip.id
        )

        let overlap = CMTime(seconds: 1.0, preferredTimescale: 600)

        XCTAssertThrowsError(try validator.validate(transition, availableOverlap: overlap))
    }

    // MARK: - Clip Validation Tests

    func testValidateWithClips() {
        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 0.5, preferredTimescale: 600),
            leadingClipID: leadingClip.id,
            trailingClipID: trailingClip.id
        )

        XCTAssertNoThrow(try validator.validate(transition, leadingClip: leadingClip, trailingClip: trailingClip, existingTransitions: []))
    }

    func testValidateWithNoOverlap() {
        let nonOverlappingTrailing = VideoClip(
            name: "Non-overlapping Clip",
            asset: TestDataFactory.makeTestAVAsset(duration: 4.0),
            timeRangeInSource: CMTimeRange(
                start: .zero,
                end: CMTime(seconds: 4.0, preferredTimescale: 600)
            ),
            timeRangeInTimeline: CMTimeRange(
                start: CMTime(seconds: 6.0, preferredTimescale: 600),
                end: CMTime(seconds: 10.0, preferredTimescale: 600)
            ),
            trackID: UUID()
        )

        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 0.5, preferredTimescale: 600),
            leadingClipID: leadingClip.id,
            trailingClipID: nonOverlappingTrailing.id
        )

        XCTAssertThrowsError(try validator.validate(transition, leadingClip: leadingClip, trailingClip: nonOverlappingTrailing, existingTransitions: [])) { error in
            guard case TransitionError.insufficientOverlap = error else {
                XCTFail("Expected insufficientOverlap error")
                return
            }
        }
    }

    // MARK: - Transition Overlap Tests

    func testTransitionOverlapDetected() {
        let existingTransition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 0.5, preferredTimescale: 600),
            leadingClipID: leadingClip.id,
            trailingClipID: trailingClip.id
        )

        let newTransition = TransitionClip(
            type: .wipe,
            duration: CMTime(seconds: 0.5, preferredTimescale: 600),
            leadingClipID: leadingClip.id,
            trailingClipID: trailingClip.id
        )

        XCTAssertThrowsError(try validator.validate(newTransition, leadingClip: leadingClip, trailingClip: trailingClip, existingTransitions: [existingTransition])) { error in
            guard case TransitionError.transitionOverlap = error else {
                XCTFail("Expected transitionOverlap error")
                return
            }
        }
    }
}
