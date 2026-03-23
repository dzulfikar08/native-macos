import XCTest
import CoreMedia
@testable import OpenScreen

final class TransitionWorkflowIntegrationTests: XCTestCase {

    func testCompleteTransitionWorkflow() {
        // 1. Create editor state
        let editorState = EditorState()

        // 2. Add overlapping clips (using clip tracks for simplicity)
        let clip1ID = UUID()
        let clip2ID = UUID()

        // 3. Create transition
        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1, preferredTimescale: 600),
            leadingClipID: clip1ID,
            trailingClipID: clip2ID,
            parameters: .crossfade,
            isEnabled: true
        )

        editorState.addTransition(transition)

        // 4. Verify transition is in timeline
        XCTAssertEqual(editorState.transitions.count, 1)
        XCTAssertEqual(editorState.transitions.first?.type, .crossfade)

        // 5. Apply preset
        let preset = BuiltInPresets.presets.first { $0.name == "Quick Dissolve" }
        XCTAssertNotNil(preset)

        let updatedTransition = preset!.makeTransition(
            leadingClipID: clip1ID,
            trailingClipID: clip2ID
        )

        editorState.updateTransition(updatedTransition)

        // 6. Verify preset applied
        XCTAssertEqual(editorState.transitions.first?.duration, CMTime(seconds: 0.5, preferredTimescale: 600))
    }

    func testMultipleTransitionsInTimeline() {
        let editorState = EditorState()

        // Create 3 clips with transitions between each
        let clipIDs = (0..<3).map { _ in UUID() }

        for i in 1..<3 {
            let transition = TransitionClip(
                type: .wipe,
                duration: CMTime(seconds: 1, preferredTimescale: 600),
                leadingClipID: clipIDs[i-1],
                trailingClipID: clipIDs[i],
                parameters: .wipe(direction: .left, softness: 0.3, border: 0),
                isEnabled: true
            )
            editorState.addTransition(transition)
        }

        XCTAssertEqual(editorState.transitions.count, 2)
    }

    func testTransitionUndoRedo() {
        let editorState = EditorState()
        let undoCoordinator = UndoRedoCoordinator()

        // Add a transition
        let clip1ID = UUID()
        let clip2ID = UUID()

        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1, preferredTimescale: 600),
            leadingClipID: clip1ID,
            trailingClipID: clip2ID,
            parameters: .crossfade,
            isEnabled: true
        )

        editorState.addTransition(transition)
        XCTAssertEqual(editorState.transitions.count, 1)

        // Undo
        undoCoordinator.undo()
        XCTAssertEqual(editorState.transitions.count, 0)

        // Redo
        undoCoordinator.redo()
        XCTAssertEqual(editorState.transitions.count, 1)
    }
}
