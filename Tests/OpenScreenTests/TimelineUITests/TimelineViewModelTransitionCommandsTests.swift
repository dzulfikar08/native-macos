import XCTest
import SwiftUI
import CoreMedia
@testable import OpenScreen

@MainActor
final class TimelineViewModelTransitionCommandsTests: XCTestCase {
    var viewModel: TimelineViewModel!
    var editorState: EditorState!

    override func setUp() async throws {
        try await super.setUp()

        editorState = EditorState.createTestState()
        viewModel = TimelineViewModel(editorState: editorState)
    }

    // MARK: - Create Transition Tests

    func testCreateTransitionCommand() {
        let (leading, trailing, _) = TestDataFactory.makeOverlappingClips()
        let track = TestDataFactory.makeTestClipTrack(clips: [leading, trailing])
        editorState.clipTracks = [track]

        viewModel.createTransition(
            type: .crossfade,
            between: leading.id,
            and: trailing.id
        )

        XCTAssertNotNil(editorState.transition(between: leading.id, and: trailing.id))
    }

    // MARK: - Delete Transition Tests

    func testDeleteTransitionCommand() {
        let transition = TestDataFactory.makeTestTransition()
        editorState.addTransition(transition)
        viewModel.syncTransitions()

        viewModel.deleteTransition(transition.id)

        XCTAssertNil(editorState.transitions.first(where: { $0.id == transition.id }))
    }

    // MARK: - Change Transition Type Tests

    func testChangeTransitionTypeCommand() {
        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )
        editorState.addTransition(transition)
        viewModel.syncTransitions()

        viewModel.changeTransitionType(transition.id, to: .wipe)

        let modified = editorState.transitions.first(where: { $0.id == transition.id })
        XCTAssertEqual(modified?.type, .wipe)
    }

    // MARK: - Undo/Redo Tests

    func testCommandsAreUndoable() {
        let (leading, trailing, _) = TestDataFactory.makeOverlappingClips()
        let track = TestDataFactory.makeTestClipTrack(clips: [leading, trailing])
        editorState.clipTracks = [track]

        // Create transition
        viewModel.createTransition(
            type: .crossfade,
            between: leading.id,
            and: trailing.id
        )

        guard let transition = editorState.transition(between: leading.id, and: trailing.id) else {
            XCTFail("Should create transition")
            return
        }

        // Undo
        viewModel.undo()

        XCTAssertNil(editorState.transition(between: leading.id, and: trailing.id))

        // Redo
        viewModel.redo()

        XCTAssertNotNil(editorState.transition(between: leading.id, and: trailing.id))
    }
}
