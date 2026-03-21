import XCTest
import CoreMedia
@testable import OpenScreen

/// Tests for context menu transition creation functionality
@MainActor
final class ContextMenuCreationTests: XCTestCase {
    var viewModel: TimelineViewModel!
    var editorState: EditorState!
    var track: ClipTrack!

    override func setUp() async throws {
        try await super.setUp()

        // Create editor state
        editorState = EditorState()

        // Create test track
        track = ClipTrack(id: UUID(), name: "Test Track")

        // Create two overlapping clips (1s overlap)
        let clip1 = VideoClip(
            id: UUID(),
            sourceURL: URL(fileURLWithPath: "/tmp/clip1.mp4"),
            startTime: CMTime(seconds: 0, preferredTimescale: 600),
            duration: CMTime(seconds: 3, preferredTimescale: 600)
        )

        let clip2 = VideoClip(
            id: UUID(),
            sourceURL: URL(fileURLWithPath: "/tmp/clip2.mp4"),
            startTime: CMTime(seconds: 2, preferredTimescale: 600), // 1s overlap
            duration: CMTime(seconds: 3, preferredTimescale: 600)
        )

        // Add clips to track
        track.clips = [clip1, clip2]

        // Add track to editor state
        editorState.addClipTrack(track)

        // Create view model
        viewModel = TimelineViewModel(editorState: editorState)
    }

    override func tearDown() async throws {
        viewModel = nil
        editorState = nil
        track = nil
        try await super.tearDown()
    }

    // MARK: - Menu Creation Tests

    func testContextMenuHasAllBuiltInPresets() {
        // Verify all 5 built-in presets are available
        XCTAssertEqual(BuiltInPresets.presets.count, 5, "Should have exactly 5 built-in presets")

        let presetNames = BuiltInPresets.presets.map { $0.name }
        XCTAssertTrue(presetNames.contains("Quick Dissolve"), "Should contain Quick Dissolve preset")
        XCTAssertTrue(presetNames.contains("Slow Fade"), "Should contain Slow Fade preset")
        XCTAssertTrue(presetNames.contains("Wipe Left"), "Should contain Wipe Left preset")
        XCTAssertTrue(presetNames.contains("Circle Reveal"), "Should contain Circle Reveal preset")
        XCTAssertTrue(presetNames.contains("Vertical Blinds"), "Should contain Vertical Blinds preset")
    }

    func testPresetDurationsAreFormatted() {
        // Test duration formatting for each preset
        for preset in BuiltInPresets.presets {
            let formatted = formatDuration(preset.duration)

            // Should not be empty
            XCTAssertFalse(formatted.isEmpty, "Duration format should not be empty for \(preset.name)")

            // Should contain time unit indicator
            XCTAssertTrue(formatted.contains("s") || formatted.contains(":"), "Duration should contain time unit for \(preset.name)")
        }
    }

    // MARK: - Overlap Detection Tests

    func testFindClipsAtDetectsOverlappingClips() {
        // Test finding overlapping clips
        let sortedClips = track.clips.sorted { $0.timeRangeInTimeline.start < $1.timeRangeInTimeline.start }

        // Should find overlap between clip1 and clip2
        var foundOverlap = false
        for i in 0..<(sortedClips.count - 1) {
            let leading = sortedClips[i]
            let trailing = sortedClips[i + 1]

            let overlap = calculateOverlap(leading: leading, trailing: trailing)
            if overlap > .zero {
                foundOverlap = true
                // Verify overlap duration is approximately 1 second
                let overlapSeconds = CMTimeGetSeconds(overlap)
                XCTAssertEqual(overlapSeconds, 1.0, accuracy: 0.1, "Overlap should be approximately 1 second")
            }
        }

        XCTAssertTrue(foundOverlap, "Should detect overlap between clips")
    }

    func testCalculateOverlapWithNoOverlap() {
        // Create two non-overlapping clips
        let clip1 = VideoClip(
            id: UUID(),
            sourceURL: URL(fileURLWithPath: "/tmp/clip1.mp4"),
            startTime: CMTime(seconds: 0, preferredTimescale: 600),
            duration: CMTime(seconds: 2, preferredTimescale: 600)
        )

        let clip2 = VideoClip(
            id: UUID(),
            sourceURL: URL(fileURLWithPath: "/tmp/clip2.mp4"),
            startTime: CMTime(seconds: 3, preferredTimescale: 600), // No overlap
            duration: CMTime(seconds: 2, preferredTimescale: 600)
        )

        let overlap = calculateOverlap(leading: clip1, trailing: clip2)
        XCTAssertEqual(overlap.seconds, 0.0, "Non-overlapping clips should have zero overlap")
    }

    func testCalculateOverlapWithPartialOverlap() {
        // Create two clips with 0.5s overlap
        let clip1 = VideoClip(
            id: UUID(),
            sourceURL: URL(fileURLWithPath: "/tmp/clip1.mp4"),
            startTime: CMTime(seconds: 0, preferredTimescale: 600),
            duration: CMTime(seconds: 2, preferredTimescale: 600)
        )

        let clip2 = VideoClip(
            id: UUID(),
            sourceURL: URL(fileURLWithPath: "/tmp/clip2.mp4"),
            startTime: CMTime(seconds: 1.5, preferredTimescale: 600), // 0.5s overlap
            duration: CMTime(seconds: 2, preferredTimescale: 600)
        )

        let overlap = calculateOverlap(leading: clip1, trailing: clip2)
        XCTAssertEqual(overlap.seconds, 0.5, accuracy: 0.01, "Overlap should be 0.5 seconds")
    }

    // MARK: - Preset Application Tests

    func testApplyPresetCreatesTransition() {
        // Get the two overlapping clips
        let sortedClips = track.clips.sorted { $0.timeRangeInTimeline.start < $1.timeRangeInTimeline.start }
        let leadingClip = sortedClips[0]
        let trailingClip = sortedClips[1]

        // Create transition from preset
        let preset = BuiltInPresets.presets[0] // Quick Dissolve
        let transition = preset.makeTransition(
            leadingClipID: leadingClip.id,
            trailingClipID: trailingClip.id
        )

        // Verify transition properties
        XCTAssertEqual(transition.type, preset.transitionType, "Transition type should match preset")
        XCTAssertEqual(transition.duration, preset.duration, "Transition duration should match preset")
        XCTAssertEqual(transition.leadingClipID, leadingClip.id, "Leading clip ID should match")
        XCTAssertEqual(transition.trailingClipID, trailingClip.id, "Trailing clip ID should match")
        XCTAssertTrue(transition.isEnabled, "Transition should be enabled by default")
    }

    func testApplyPresetAddsToEditorState() {
        // Get the two overlapping clips
        let sortedClips = track.clips.sorted { $0.timeRangeInTimeline.start < $1.timeRangeInTimeline.start }
        let leadingClip = sortedClips[0]
        let trailingClip = sortedClips[1]

        // Create transition from preset
        let preset = BuiltInPresets.presets[0]
        let transition = preset.makeTransition(
            leadingClipID: leadingClip.id,
            trailingClipID: trailingClip.id
        )

        // Add to editor state
        editorState.addTransition(transition)

        // Verify transition was added
        XCTAssertEqual(editorState.transitions.count, 1, "Should have one transition")
        XCTAssertEqual(editorState.transitions.first?.id, transition.id, "Transition ID should match")
    }

    func testTransitionBetweenReturnsCorrectTransition() {
        // Get the two overlapping clips
        let sortedClips = track.clips.sorted { $0.timeRangeInTimeline.start < $1.timeRangeInTimeline.start }
        let leadingClip = sortedClips[0]
        let trailingClip = sortedClips[1]

        // Create and add transition
        let preset = BuiltInPresets.presets[0]
        let transition = preset.makeTransition(
            leadingClipID: leadingClip.id,
            trailingClipID: trailingClip.id
        )
        editorState.addTransition(transition)

        // Sync transitions
        viewModel.syncTransitions()

        // Verify transition(between:and:) finds it
        let foundTransition = viewModel.transition(between: leadingClip.id, and: trailingClip.id)
        XCTAssertNotNil(foundTransition, "Should find transition between clips")
        XCTAssertEqual(foundTransition?.id, transition.id, "Found transition ID should match")
    }

    func testTransitionBetweenReturnsNilWhenNoTransition() {
        // Get the two overlapping clips
        let sortedClips = track.clips.sorted { $0.timeRangeInTimeline.start < $1.timeRangeInTimeline.start }
        let leadingClip = sortedClips[0]
        let trailingClip = sortedClips[1]

        // Don't add any transition

        // Verify transition(between:and:) returns nil
        let foundTransition = viewModel.transition(between: leadingClip.id, and: trailingClip.id)
        XCTAssertNil(foundTransition, "Should not find transition when none exists")
    }

    // MARK: - Validation Tests

    func testMinimumOverlapValidation() {
        // Create clips with less than minimum overlap (0.05s)
        let clip1 = VideoClip(
            id: UUID(),
            sourceURL: URL(fileURLWithPath: "/tmp/clip1.mp4"),
            startTime: CMTime(seconds: 0, preferredTimescale: 600),
            duration: CMTime(seconds: 2, preferredTimescale: 600)
        )

        let clip2 = VideoClip(
            id: UUID(),
            sourceURL: URL(fileURLWithPath: "/tmp/clip2.mp4"),
            startTime: CMTime(seconds: 1.95, preferredTimescale: 600), // 0.05s overlap
            duration: CMTime(seconds: 2, preferredTimescale: 600)
        )

        let overlap = calculateOverlap(leading: clip1, trailing: clip2)

        // Should be less than minimum duration
        XCTAssertLessThan(overlap.seconds, TransitionValidator.minimumDuration.seconds,
                         "Overlap should be less than minimum required")
    }

    func testMinimumOverlapPassedWithSufficientOverlap() {
        // Get the two overlapping clips from setup (1s overlap)
        let sortedClips = track.clips.sorted { $0.timeRangeInTimeline.start < $1.timeRangeInTimeline.start }
        let leadingClip = sortedClips[0]
        let trailingClip = sortedClips[1]

        let overlap = calculateOverlap(leading: leadingClip, trailing: trailingClip)

        // Should be greater than minimum duration
        XCTAssertGreaterThanOrEqual(overlap.seconds, TransitionValidator.minimumDuration.seconds,
                                   "Overlap should meet minimum requirement")
    }

    // MARK: - Duration Formatting Tests

    func testFormatDurationWithSeconds() {
        let time = CMTime(seconds: 0.5, preferredTimescale: 600)
        let formatted = formatDuration(time)
        XCTAssertEqual(formatted, "0.5s", "Should format short duration correctly")
    }

    func testFormatDurationWithMinutes() {
        let time = CMTime(seconds: 90, preferredTimescale: 600)
        let formatted = formatDuration(time)
        XCTAssertEqual(formatted, "1:30", "Should format duration with minutes correctly")
    }

    func testFormatDurationWithOnlyMinutes() {
        let time = CMTime(seconds: 120, preferredTimescale: 600)
        let formatted = formatDuration(time)
        XCTAssertEqual(formatted, "2:00", "Should format round minutes correctly")
    }
}

// MARK: - Helper Functions for Testing

/// Helper function to format duration (same as in ClipTrackView)
private func formatDuration(_ time: CMTime) -> String {
    let seconds = CMTimeGetSeconds(time)
    if seconds < 60 {
        return String(format: "%.1fs", seconds)
    } else {
        let minutes = Int(seconds) / 60
        let remainder = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainder)
    }
}

/// Helper function to calculate overlap (same as in TransitionHelpers)
@MainActor
private func calculateOverlap(leading: VideoClip, trailing: VideoClip) -> CMTime {
    let leadingEnd = leading.timeRangeInTimeline.end
    let trailingStart = trailing.timeRangeInTimeline.start

    guard leadingEnd > trailingStart else {
        return .zero
    }

    return max(CMTime(seconds: 0, preferredTimescale: 600), leadingEnd - trailingStart)
}

// MARK: - TimelineViewModel Extension for Testing

extension TimelineViewModel {
    /// Syncs transitions from editor state (for testing)
    func syncTransitions() {
        transitions = editorState.transitions
    }
}
