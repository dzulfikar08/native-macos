import XCTest
import SwiftUI
import CoreMedia
@testable import OpenScreen

@MainActor
final class TransitionFactoryTests: XCTestCase {
    var editorState: EditorState!

    override func setUp() async throws {
        try await super.setUp()
        editorState = EditorState.createTestState()
    }

    // MARK: - Creation Tests

    func testCreateTransitionWithDefaults() {
        let (leading, trailing, _) = TestDataFactory.makeOverlappingClips()
        editorState.clipTracks = [TestDataFactory.makeTestClipTrack(clips: [leading, trailing])]

        let transition = TransitionFactory.createTransition(
            type: .crossfade,
            between: leading.id,
            and: trailing.id,
            in: editorState
        )

        XCTAssertNotNil(transition)
        XCTAssertEqual(transition?.type, .crossfade)
        XCTAssertEqual(transition?.leadingClipID, leading.id)
        XCTAssertEqual(transition?.trailingClipID, trailing.id)
    }

    // MARK: - Duration Capping Tests

    func testDurationCappedAtOverlap() {
        let leading = VideoClip(
            id: UUID(),
            name: "Leading",
            timeRangeInTimeline: CMTimeRange(
                start: CMTime(seconds: 0, preferredTimescale: 600),
                duration: CMTime(seconds: 3.0, preferredTimescale: 600)
            ),
            sourceRange: CMTimeRange(
                start: .zero,
                duration: CMTime(seconds: 3.0, preferredTimescale: 600)
            ),
            trackID: UUID()
        )

        let trailing = VideoClip(
            id: UUID(),
            name: "Trailing",
            timeRangeInTimeline: CMTimeRange(
                start: CMTime(seconds: 2.5, preferredTimescale: 600), // 0.5s overlap
                duration: CMTime(seconds: 3.0, preferredTimescale: 600)
            ),
            sourceRange: CMTimeRange(
                start: .zero,
                duration: CMTime(seconds: 3.0, preferredTimescale: 600)
            ),
            trackID: UUID()
        )

        let track = TestDataFactory.makeTestClipTrack(clips: [leading, trailing])
        editorState.clipTracks = [track]

        // Crossfade defaults to 1.0s but overlap is only 0.5s
        let transition = TransitionFactory.createTransition(
            type: .crossfade,
            between: leading.id,
            and: trailing.id,
            in: editorState
        )

        XCTAssertNotNil(transition)
        XCTAssertEqual(transition?.duration.seconds, 0.5, accuracy: 0.01)
    }

    // MARK: - Insufficient Overlap Tests

    func testReturnNilForInsufficientOverlap() {
        let leading = VideoClip(
            id: UUID(),
            name: "Leading",
            timeRangeInTimeline: CMTimeRange(
                start: CMTime(seconds: 0, preferredTimescale: 600),
                duration: CMTime(seconds: 3.0, preferredTimescale: 600)
            ),
            sourceRange: CMTimeRange(
                start: .zero,
                duration: CMTime(seconds: 3.0, preferredTimescale: 600)
            ),
            trackID: UUID()
        )

        let trailing = VideoClip(
            id: UUID(),
            name: "Trailing",
            timeRangeInTimeline: CMTimeRange(
                start: CMTime(seconds: 2.9, preferredTimescale: 600), // 0.1s overlap
                duration: CMTime(seconds: 3.0, preferredTimescale: 600)
            ),
            sourceRange: CMTimeRange(
                start: .zero,
                duration: CMTime(seconds: 3.0, preferredTimescale: 600)
            ),
            trackID: UUID()
        )

        let track = TestDataFactory.makeTestClipTrack(clips: [leading, trailing])
        editorState.clipTracks = [track]

        // Overlap is less than minimum duration
        let transition = TransitionFactory.createTransition(
            type: .crossfade,
            between: leading.id,
            and: trailing.id,
            in: editorState
        )

        XCTAssertNil(transition)
    }

    // MARK: - Default Durations Tests

    func testDefaultDurationsByType() {
        let (leading, trailing, _) = TestDataFactory.makeOverlappingClips()
        let track = TestDataFactory.makeTestClipTrack(clips: [leading, trailing])
        editorState.clipTracks = [track]

        let crossfade = TransitionFactory.createTransition(
            type: .crossfade,
            between: leading.id,
            and: trailing.id,
            in: editorState
        )

        let fadeToColor = TransitionFactory.createTransition(
            type: .fadeToColor,
            between: leading.id,
            and: trailing.id,
            in: editorState
        )

        XCTAssertEqual(crossfade?.duration.seconds, 1.0, accuracy: 0.01)
        XCTAssertEqual(fadeToColor?.duration.seconds, 0.5, accuracy: 0.01)
    }
}
