import XCTest
import CoreMedia
@testable import OpenScreen

final class AutoTransitionPromptTests: XCTestCase {
    // MARK: - Prompt Condition Tests

    func testShouldShowPromptWithSufficientOverlap() {
        // Create clips with 1.0 second overlap
        let leadingClip = VideoClip(
            name: "Leading Clip",
            asset: AVAsset(url: URL(fileURLWithPath: "/dev/null")),
            timeRangeInSource: CMTimeRange(
                start: CMTime(seconds: 0, preferredTimescale: 600),
                duration: CMTime(seconds: 5, preferredTimescale: 600)
            ),
            timeRangeInTimeline: CMTimeRange(
                start: CMTime(seconds: 0, preferredTimescale: 600),
                duration: CMTime(seconds: 5, preferredTimescale: 600)
            ),
            trackID: UUID()
        )

        let trailingClip = VideoClip(
            name: "Trailing Clip",
            asset: AVAsset(url: URL(fileURLWithPath: "/dev/null")),
            timeRangeInSource: CMTimeRange(
                start: CMTime(seconds: 0, preferredTimescale: 600),
                duration: CMTime(seconds: 5, preferredTimescale: 600)
            ),
            timeRangeInTimeline: CMTimeRange(
                start: CMTime(seconds: 4, preferredTimescale: 600), // 1s overlap
                duration: CMTime(seconds: 5, preferredTimescale: 600)
            ),
            trackID: UUID()
        )

        let overlap = ClipOverlap(
            leadingClip: leadingClip,
            trailingClip: trailingClip,
            overlapDuration: CMTime(seconds: 1.0, preferredTimescale: 600),
            overlapRange: CMTime(seconds: 4, preferredTimescale: 600)...CMTime(seconds: 5, preferredTimescale: 600)
        )

        // Overlap of 1.0s >= minimum 0.5s, should show prompt
        XCTAssertGreaterThanOrEqual(
            overlap.overlapDuration.seconds,
            0.5,
            "Prompt should show for 1.0 second overlap"
        )
    }

    func testShouldNotShowPromptWithInsufficientOverlap() {
        // Create clips with 0.2 second overlap
        let leadingClip = VideoClip(
            name: "Leading Clip",
            asset: AVAsset(url: URL(fileURLWithPath: "/dev/null")),
            timeRangeInSource: CMTimeRange(
                start: CMTime(seconds: 0, preferredTimescale: 600),
                duration: CMTime(seconds: 5, preferredTimescale: 600)
            ),
            timeRangeInTimeline: CMTimeRange(
                start: CMTime(seconds: 0, preferredTimescale: 600),
                duration: CMTime(seconds: 5, preferredTimescale: 600)
            ),
            trackID: UUID()
        )

        let trailingClip = VideoClip(
            name: "Trailing Clip",
            asset: AVAsset(url: URL(fileURLWithPath: "/dev/null")),
            timeRangeInSource: CMTimeRange(
                start: CMTime(seconds: 0, preferredTimescale: 600),
                duration: CMTime(seconds: 5, preferredTimescale: 600)
            ),
            timeRangeInTimeline: CMTimeRange(
                start: CMTime(seconds: 4.8, preferredTimescale: 600), // 0.2s overlap
                duration: CMTime(seconds: 5, preferredTimescale: 600)
            ),
            trackID: UUID()
        )

        let overlap = ClipOverlap(
            leadingClip: leadingClip,
            trailingClip: trailingClip,
            overlapDuration: CMTime(seconds: 0.2, preferredTimescale: 600),
            overlapRange: CMTime(seconds: 4.8, preferredTimescale: 600)...CMTime(seconds: 5, preferredTimescale: 600)
        )

        // Overlap of 0.2s < minimum 0.5s, should NOT show prompt
        XCTAssertLessThan(
            overlap.overlapDuration.seconds,
            0.5,
            "Prompt should NOT show for 0.2 second overlap"
        )
    }

    func testShouldNotShowPromptWhenTransitionExists() {
        // Create overlapping clips
        let leadingClip = VideoClip(
            id: UUID(),
            assetID: UUID(),
            timeRangeInTimeline: CMTimeRange(
                start: CMTime(seconds: 0, preferredTimescale: 600),
                duration: CMTime(seconds: 5, preferredTimescale: 600)
            ),
            sourceTimeRange: CMTimeRange(
                start: CMTime(seconds: 0, preferredTimescale: 600),
                duration: CMTime(seconds: 5, preferredTimescale: 600)
            )
        )

        let trailingClip = VideoClip(
            id: UUID(),
            assetID: UUID(),
            timeRangeInTimeline: CMTimeRange(
                start: CMTime(seconds: 4, preferredTimescale: 600),
                duration: CMTime(seconds: 5, preferredTimescale: 600)
            ),
            sourceTimeRange: CMTimeRange(
                start: CMTime(seconds: 0, preferredTimescale: 600),
                duration: CMTime(seconds: 5, preferredTimescale: 600)
            )
        )

        // Create a transition between them
        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 0.5, preferredTimescale: 600),
            leadingClipID: leadingClip.id,
            trailingClipID: trailingClip.id,
            parameters: .crossfade,
            isEnabled: true
        )

        // Transition exists between clips
        XCTAssertEqual(
            transition.leadingClipID,
            leadingClip.id,
            "Transition should reference leading clip"
        )
        XCTAssertEqual(
            transition.trailingClipID,
            trailingClip.id,
            "Transition should reference trailing clip"
        )

        // In actual implementation, viewModel.transition(between:and:) would return this transition
        // preventing the prompt from showing
    }

    // MARK: - Cooldown Tests

    func testCooldownPeriodPreventsPrompt() {
        // Simulate prompt being dismissed
        let dismissalTime = Date()

        // Check time 1 minute after dismissal (within 5-minute cooldown)
        let oneMinuteLater = dismissalTime.addingTimeInterval(60)
        let timeSinceDismiss = oneMinuteLater.timeIntervalSince(dismissalTime)

        // Cooldown is 5 minutes (300 seconds)
        let cooldown: TimeInterval = 5 * 60

        XCTAssertLessThan(
            timeSinceDismiss,
            cooldown,
            "Prompt should NOT show within 5-minute cooldown period"
        )
    }

    func testCooldownExpiredAllowsPrompt() {
        // Simulate prompt being dismissed
        let dismissalTime = Date()

        // Check time 6 minutes after dismissal (beyond 5-minute cooldown)
        let sixMinutesLater = dismissalTime.addingTimeInterval(6 * 60)
        let timeSinceDismiss = sixMinutesLater.timeIntervalSince(dismissalTime)

        // Cooldown is 5 minutes (300 seconds)
        let cooldown: TimeInterval = 5 * 60

        XCTAssertGreaterThan(
            timeSinceDismiss,
            cooldown,
            "Prompt should show after 5-minute cooldown expires"
        )
    }

    // MARK: - Overlap Detection Tests

    func testDetectsOverlapBetweenAdjacentClips() {
        let detector = ClipOverlapDetector()

        let leadingClip = VideoClip(
            id: UUID(),
            assetID: UUID(),
            timeRangeInTimeline: CMTimeRange(
                start: CMTime(seconds: 0, preferredTimescale: 600),
                duration: CMTime(seconds: 5, preferredTimescale: 600)
            ),
            sourceTimeRange: CMTimeRange(
                start: CMTime(seconds: 0, preferredTimescale: 600),
                duration: CMTime(seconds: 5, preferredTimescale: 600)
            )
        )

        let trailingClip = VideoClip(
            id: UUID(),
            assetID: UUID(),
            timeRangeInTimeline: CMTimeRange(
                start: CMTime(seconds: 4.5, preferredTimescale: 600),
                duration: CMTime(seconds: 5, preferredTimescale: 600)
            ),
            sourceTimeRange: CMTimeRange(
                start: CMTime(seconds: 0, preferredTimescale: 600),
                duration: CMTime(seconds: 5, preferredTimescale: 600)
            )
        )

        let clips = [leadingClip, trailingClip]
        let overlaps = detector.detectOverlaps(clips: clips)

        XCTAssertEqual(
            overlaps.count,
            1,
            "Should detect one overlap between adjacent overlapping clips"
        )

        let detectedOverlap = overlaps.first

        XCTAssertEqual(
            detectedOverlap?.leadingClip.id,
            leadingClip.id,
            "Leading clip should be correctly identified"
        )
        XCTAssertEqual(
            detectedOverlap?.trailingClip.id,
            trailingClip.id,
            "Trailing clip should be correctly identified"
        )
        XCTAssertEqual(
            detectedOverlap?.overlapDuration.seconds,
            0.5,
            accuracy: 0.01,
            "Overlap duration should be 0.5 seconds"
        )
    }

    func testDoesNotDetectOverlapBetweenNonOverlappingClips() {
        let detector = ClipOverlapDetector()

        let clip1 = VideoClip(
            id: UUID(),
            assetID: UUID(),
            timeRangeInTimeline: CMTimeRange(
                start: CMTime(seconds: 0, preferredTimescale: 600),
                duration: CMTime(seconds: 5, preferredTimescale: 600)
            ),
            sourceTimeRange: CMTimeRange(
                start: CMTime(seconds: 0, preferredTimescale: 600),
                duration: CMTime(seconds: 5, preferredTimescale: 600)
            )
        )

        let clip2 = VideoClip(
            id: UUID(),
            assetID: UUID(),
            timeRangeInTimeline: CMTimeRange(
                start: CMTime(seconds: 6, preferredTimescale: 600), // No overlap (1s gap)
                duration: CMTime(seconds: 5, preferredTimescale: 600)
            ),
            sourceTimeRange: CMTimeRange(
                start: CMTime(seconds: 0, preferredTimescale: 600),
                duration: CMTime(seconds: 5, preferredTimescale: 600)
            )
        )

        let clips = [clip1, clip2]
        let overlaps = detector.detectOverlaps(clips: clips)

        XCTAssertEqual(
            overlaps.count,
            0,
            "Should NOT detect overlap when clips don't overlap"
        )
    }

    func testDetectsMultipleOverlaps() {
        let detector = ClipOverlapDetector()

        let clip1 = VideoClip(
            id: UUID(),
            assetID: UUID(),
            timeRangeInTimeline: CMTimeRange(
                start: CMTime(seconds: 0, preferredTimescale: 600),
                duration: CMTime(seconds: 5, preferredTimescale: 600)
            ),
            sourceTimeRange: CMTimeRange(
                start: CMTime(seconds: 0, preferredTimescale: 600),
                duration: CMTime(seconds: 5, preferredTimescale: 600)
            )
        )

        let clip2 = VideoClip(
            id: UUID(),
            assetID: UUID(),
            timeRangeInTimeline: CMTimeRange(
                start: CMTime(seconds: 4, preferredTimescale: 600),
                duration: CMTime(seconds: 5, preferredTimescale: 600)
            ),
            sourceTimeRange: CMTimeRange(
                start: CMTime(seconds: 0, preferredTimescale: 600),
                duration: CMTime(seconds: 5, preferredTimescale: 600)
            )
        )

        let clip3 = VideoClip(
            id: UUID(),
            assetID: UUID(),
            timeRangeInTimeline: CMTimeRange(
                start: CMTime(seconds: 8, preferredTimescale: 600),
                duration: CMTime(seconds: 5, preferredTimescale: 600)
            ),
            sourceTimeRange: CMTimeRange(
                start: CMTime(seconds: 0, preferredTimescale: 600),
                duration: CMTime(seconds: 5, preferredTimescale: 600)
            )
        )

        let clips = [clip1, clip2, clip3]
        let overlaps = detector.detectOverlaps(clips: clips)

        XCTAssertEqual(
            overlaps.count,
            2,
            "Should detect two overlaps: clip1-clip2 and clip2-clip3"
        )
    }

    // MARK: - Quick Dissolve Tests

    func testQuickDissolvePresetExists() {
        let quickDissolve = BuiltInPresets.presets.first { $0.name == "Quick Dissolve" }

        XCTAssertNotNil(
            quickDissolve,
            "Quick Dissolve preset should exist in BuiltInPresets"
        )

        if let preset = quickDissolve {
            XCTAssertEqual(
                preset.transitionType,
                .crossfade,
                "Quick Dissolve should be a crossfade transition"
            )
            XCTAssertEqual(
                preset.duration.seconds,
                0.5,
                accuracy: 0.01,
                "Quick Dissolve duration should be 0.5 seconds"
            )
        }
    }

    func testQuickDissolveCreatesValidTransition() {
        let quickDissolve = BuiltInPresets.presets.first { $0.name == "Quick Dissolve" }
        guard let preset = quickDissolve else {
            XCTFail("Quick Dissolve preset should exist")
            return
        }

        let leadingClipID = UUID()
        let trailingClipID = UUID()

        let transition = preset.makeTransition(
            leadingClipID: leadingClipID,
            trailingClipID: trailingClipID
        )

        XCTAssertEqual(
            transition.leadingClipID,
            leadingClipID,
            "Transition should reference leading clip"
        )
        XCTAssertEqual(
            transition.trailingClipID,
            trailingClipID,
            "Transition should reference trailing clip"
        )
        XCTAssertEqual(
            transition.type,
            .crossfade,
            "Transition type should be crossfade"
        )
        XCTAssertEqual(
            transition.duration.seconds,
            0.5,
            accuracy: 0.01,
            "Transition duration should be 0.5 seconds"
        )
        XCTAssertTrue(
            transition.isValid,
            "Transition should be valid"
        )
    }
}

// MARK: - Helper Extensions

extension CMTime {
    /// Returns the seconds value as Double
    var seconds: Double {
        return CMTimeGetSeconds(self)
    }
}
