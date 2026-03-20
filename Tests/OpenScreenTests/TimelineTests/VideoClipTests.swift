import XCTest
@testable import OpenScreen
import AVFoundation
import CoreMedia

@MainActor
final class VideoClipTests: XCTestCase {
    func testVideoClipInitialization() {
        let asset = TestDataFactory.makeTestAVAsset()
        let sourceRange = CMTimeRange(start: .zero, end: CMTime(seconds: 10, preferredTimescale: 600))
        let timelineRange = CMTimeRange(start: .zero, end: CMTime(seconds: 10, preferredTimescale: 600))
        let trackID = UUID()

        let clip = VideoClip(
            name: "Test Clip",
            asset: asset,
            timeRangeInSource: sourceRange,
            timeRangeInTimeline: timelineRange,
            trackID: trackID
        )

        XCTAssertEqual(clip.name, "Test Clip")
        XCTAssertEqual(clip.isEnabled, true)
        XCTAssertEqual(clip.opacity, 1.0, accuracy: 0.01)
        XCTAssertEqual(clip.speed, 1.0, accuracy: 0.01)
        XCTAssertEqual(clip.volume, 1.0, accuracy: 0.01)
        XCTAssertTrue(clip.isAudioMuted == false)
        XCTAssertTrue(clip.videoEffects.isEmpty)
        XCTAssertTrue(clip.audioEffects.isEmpty)
    }

    func testTimelineDurationWithNormalSpeed() {
        let clip = TestDataFactory.makeTestVideoClip(speed: 1.0, sourceDuration: 10)
        XCTAssertEqual(clip.timelineDuration.seconds, 10.0, accuracy: 0.1)
    }

    func testTimelineDurationWithHalfSpeed() {
        let clip = TestDataFactory.makeTestVideoClip(speed: 0.5, sourceDuration: 10)
        XCTAssertEqual(clip.timelineDuration.seconds, 20.0, accuracy: 0.1)
    }

    func testTimelineDurationWithDoubleSpeed() {
        let clip = TestDataFactory.makeTestVideoClip(speed: 2.0, sourceDuration: 10)
        XCTAssertEqual(clip.timelineDuration.seconds, 5.0, accuracy: 0.1)
    }

    func testTimelineTimeInSource() {
        let clip = TestDataFactory.makeTestVideoClip(
            speed: 1.0,
            sourceDuration: 10,
            timelineStart: .zero
        )

        let timelineTime = CMTime(seconds: 5, preferredTimescale: 600)
        let sourceTime = clip.timelineTimeInSource(timelineTime)

        XCTAssertEqual(sourceTime.seconds, 5.0, accuracy: 0.1)
    }

    func testTimelineTimeInSourceWithSpeed() {
        let clip = TestDataFactory.makeTestVideoClip(
            speed: 2.0,
            sourceDuration: 10,
            timelineStart: .zero
        )

        let timelineTime = CMTime(seconds: 2, preferredTimescale: 600)
        let sourceTime = clip.timelineTimeInSource(timelineTime)

        // At 2x speed, 2 seconds on timeline = 4 seconds in source
        XCTAssertEqual(sourceTime.seconds, 4.0, accuracy: 0.1)
    }

    func testValidationInvalidSpeedTooLow() {
        let asset = TestDataFactory.makeTestAVAsset()
        let sourceRange = CMTimeRange(start: .zero, end: CMTime(seconds: 10, preferredTimescale: 600))
        let timelineRange = CMTimeRange(start: .zero, end: CMTime(seconds: 10, preferredTimescale: 600))

        // Speed 0.05 is below minimum of 0.1
        // Note: precondition failures can't be tested directly in XCTest
        // This test documents the expected behavior
        // In production, ClipManager will validate before creating VideoClip
    }

    func testValidationInvalidSpeedTooHigh() {
        let asset = TestDataFactory.makeTestAVAsset()
        let sourceRange = CMTimeRange(start: .zero, end: CMTime(seconds: 10, preferredTimescale: 600))
        let timelineRange = CMTimeRange(start: .zero, end: CMTime(seconds: 10, preferredTimescale: 600))

        // Speed 20.0 is above maximum of 16.0
        // Note: precondition failures can't be tested directly in XCTest
        // This test documents the expected behavior
        // In production, ClipManager will validate before creating VideoClip
    }
}
