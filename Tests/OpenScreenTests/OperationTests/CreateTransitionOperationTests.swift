import XCTest
import SwiftUI
import CoreMedia
@testable import OpenScreen

@MainActor
final class CreateTransitionOperationTests: XCTestCase {
    var editorState: EditorState!

    override func setUp() async throws {
        try await super.setUp()
        editorState = EditorState()
    }

    // MARK: - Creation Tests

    func testCreateTransitionOperation() {
        let (leading, trailing, _) = TestDataFactory.makeOverlappingClips()
        let track = TestDataFactory.makeTestClipTrack(clips: [leading, trailing])
        editorState.addClipTrack(track)

        let operation = CreateTransitionOperation(
            transitionType: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: leading.id,
            trailingClipID: trailing.id,
            editorState: editorState
        )

        try! operation.execute()

        XCTAssertNotNil(editorState.transition(between: leading.id, and: trailing.id))
        XCTAssertEqual(editorState.transitions.count, 1)
    }

    // MARK: - Undo Tests

    func testCreateTransitionUndo() {
        let (leading, trailing, _) = TestDataFactory.makeOverlappingClips()
        let track = TestDataFactory.makeTestClipTrack(clips: [leading, trailing])
        editorState.addClipTrack(track)

        let operation = CreateTransitionOperation(
            transitionType: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: leading.id,
            trailingClipID: trailing.id,
            editorState: editorState
        )

        try! operation.execute()
        try! operation.undo()

        XCTAssertNil(editorState.transition(between: leading.id, and: trailing.id))
        XCTAssertEqual(editorState.transitions.count, 0)
    }

    // MARK: - Redo Tests

    func testCreateTransitionRedo() {
        let (leading, trailing, _) = TestDataFactory.makeOverlappingClips()
        let track = TestDataFactory.makeTestClipTrack(clips: [leading, trailing])
        editorState.addClipTrack(track)

        let operation = CreateTransitionOperation(
            transitionType: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: leading.id,
            trailingClipID: trailing.id,
            editorState: editorState
        )

        try! operation.execute()
        try! operation.undo()
        try! operation.redo()

        XCTAssertNotNil(editorState.transition(between: leading.id, and: trailing.id))
        XCTAssertEqual(editorState.transitions.count, 1)
    }

    // MARK: - Validation Tests

    func testCreateTransitionValidatesOverlap() {
        // Create non-overlapping clips
        let clip1 = VideoClip(
            id: UUID(),
            name: "Clip 1",
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

        let clip2 = VideoClip(
            id: UUID(),
            name: "Clip 2",
            timeRangeInTimeline: CMTimeRange(
                start: CMTime(seconds: 5, preferredTimescale: 600),
                duration: CMTime(seconds: 3.0, preferredTimescale: 600)
            ),
            sourceRange: CMTimeRange(
                start: .zero,
                duration: CMTime(seconds: 3.0, preferredTimescale: 600)
            ),
            trackID: UUID()
        )

        editorState.clips = [clip1, clip2]

        let operation = CreateTransitionOperation(
            transitionType: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: clip1.id,
            trailingClipID: clip2.id,
            editorState: editorState
        )

        XCTAssertThrowsError(try operation.execute()) { error in
            XCTAssertTrue(error is TransitionError)
        }
    }
}
