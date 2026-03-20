import XCTest
import SwiftUI
import CoreMedia
@testable import OpenScreen

@MainActor
final class UndoRedoCoordinatorTransitionTests: XCTestCase {
    var coordinator: UndoRedoCoordinator!
    var editorState: EditorState!

    override func setUp() async throws {
        try await super.setUp()

        editorState = EditorState.createTestState()
        coordinator = UndoRedoCoordinator(editorState: editorState)
    }

    // MARK: - Create Transition Tests

    func testExecuteCreateTransition() {
        let (leading, trailing, _) = TestDataFactory.makeOverlappingClips()
        let track = TestDataFactory.makeTestClipTrack(clips: [leading, trailing])
        editorState.clipTracks = [track]

        let result = coordinator.executeCreateTransition(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: leading.id,
            trailingClipID: trailing.id
        )

        switch result {
        case .success:
            XCTAssertNotNil(editorState.transition(between: leading.id, and: trailing.id))
        case .failure(let error):
            XCTFail("Should succeed: \(error)")
        }
    }

    // MARK: - Delete Transition Tests

    func testExecuteDeleteTransition() {
        let transition = TestDataFactory.makeTestTransition()
        editorState.addTransition(transition)

        let result = coordinator.executeDeleteTransition(transitionID: transition.id)

        switch result {
        case .success:
            XCTAssertNil(editorState.transitions.first(where: { $0.id == transition.id }))
        case .failure(let error):
            XCTFail("Should succeed: \(error)")
        }
    }

    // MARK: - Modify Transition Tests

    func testExecuteModifyTransition() {
        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )
        editorState.addTransition(transition)

        let result = coordinator.executeModifyTransition(
            transitionID: transition.id,
            newType: .wipe
        )

        switch result {
        case .success:
            let modified = editorState.transitions.first(where: { $0.id == transition.id })
            XCTAssertEqual(modified?.type, .wipe)
        case .failure(let error):
            XCTFail("Should succeed: \(error)")
        }
    }

    // MARK: - Undo/Redo Tests

    func testTransitionUndoRedoThroughCoordinator() {
        let (leading, trailing, _) = TestDataFactory.makeOverlappingClips()
        let track = TestDataFactory.makeTestClipTrack(clips: [leading, trailing])
        editorState.clipTracks = [track]

        // Create transition
        let createResult = coordinator.executeCreateTransition(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: leading.id,
            trailingClipID: trailing.id
        )

        guard case .success = createResult,
              let transition = editorState.transition(between: leading.id, and: trailing.id) else {
            XCTFail("Should create transition")
            return
        }

        // Undo
        let undoResult = coordinator.undo()
        guard case .success = undoResult else {
            XCTFail("Undo should succeed")
            return
        }

        XCTAssertNil(editorState.transition(between: leading.id, and: trailing.id))

        // Redo
        let redoResult = coordinator.redo()
        guard case .success = redoResult else {
            XCTFail("Redo should succeed")
            return
        }

        XCTAssertNotNil(editorState.transition(between: leading.id, and: trailing.id))
    }
}
