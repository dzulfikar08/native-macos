import XCTest
import SwiftUI
import CoreMedia
@testable import OpenScreen

@MainActor
final class ModifyTransitionOperationTests: XCTestCase {
    var editorState: EditorState!

    override func setUp() async throws {
        try await super.setUp()
        editorState = EditorState.createTestState()
    }

    // MARK: - Type Modification Tests

    func testModifyTransitionType() {
        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )
        editorState.addTransition(transition)

        let operation = ModifyTransitionOperation(
            transitionID: transition.id,
            newType: .wipe,
            editorState: editorState
        )

        try! operation.execute()

        let modified = editorState.transitions.first(where: { $0.id == transition.id })
        XCTAssertEqual(modified?.type, .wipe)
    }

    // MARK: - Duration Modification Tests

    func testModifyTransitionDuration() {
        let (leading, trailing, _) = TestDataFactory.makeOverlappingClips()
        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: leading.id,
            trailingClipID: trailing.id
        )

        // Set up tracks
        let track = TestDataFactory.makeTestClipTrack(clips: [leading, trailing])
        editorState.clipTracks = [track]
        editorState.addTransition(transition)

        let newDuration = CMTime(seconds: 1.5, preferredTimescale: 600)
        let operation = ModifyTransitionOperation(
            transitionID: transition.id,
            newDuration: newDuration,
            editorState: editorState
        )

        try! operation.execute()

        let modified = editorState.transitions.first(where: { $0.id == transition.id })
        XCTAssertEqual(modified?.duration, newDuration)
    }

    // MARK: - Undo Tests

    func testModifyTransitionUndo() {
        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )
        editorState.addTransition(transition)

        let operation = ModifyTransitionOperation(
            transitionID: transition.id,
            newType: .wipe,
            editorState: editorState
        )

        try! operation.execute()

        var modified = editorState.transitions.first(where: { $0.id == transition.id })
        XCTAssertEqual(modified?.type, .wipe)

        try! operation.undo()

        let restored = editorState.transitions.first(where: { $0.id == transition.id })
        XCTAssertEqual(restored?.type, .crossfade)
    }

    // MARK: - Validation Tests

    func testModifyTransitionDurationValidatesOverlap() {
        let (leading, trailing, overlap) = TestDataFactory.makeOverlappingClips()
        let transition = TransitionClip(
            type: .crossfade,
            duration: overlap.duration, // At maximum
            leadingClipID: leading.id,
            trailingClipID: trailing.id
        )

        // Set up tracks
        let track = TestDataFactory.makeTestClipTrack(clips: [leading, trailing])
        editorState.clipTracks = [track]
        editorState.addTransition(transition)

        // Try to extend beyond overlap
        let newDuration = CMTimeAdd(overlap.duration, CMTime(seconds: 0.5, preferredTimescale: 600))
        let operation = ModifyTransitionOperation(
            transitionID: transition.id,
            newDuration: newDuration,
            editorState: editorState
        )

        XCTAssertThrowsError(try operation.execute()) { error in
            XCTAssertTrue(error is TransitionError)
        }
    }
}
