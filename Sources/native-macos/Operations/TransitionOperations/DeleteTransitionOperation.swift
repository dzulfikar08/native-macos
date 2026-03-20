import Foundation
import CoreMedia
import AVFoundation

/// Deletes a transition from the timeline
final class DeleteTransitionOperation: BaseClipOperation {
    private let transitionID: UUID
    private var deletedTransition: TransitionClip?

    init(
        transitionID: UUID,
        editorState: EditorState
    ) {
        self.transitionID = transitionID

        super.init(
            description: "Delete transition",
            editorState: editorState,
            clipManager: nil
        )
    }

    override func execute() throws {
        guard let editorState = editorState else {
            throw TransitionError.clipsNotFound(leadingClipID: nil, trailingClipID: nil)
        }

        // Find and capture transition
        guard let transition = editorState.transitions.first(where: { $0.id == transitionID }) else {
            throw TransitionError.clipsNotFound(leadingClipID: nil, trailingClipID: nil)
        }

        deletedTransition = transition

        // Remove from editor state
        editorState.removeTransition(id: transitionID)
    }

    override func undo() throws {
        guard let transition = deletedTransition else {
            throw TransitionError.clipsNotFound(leadingClipID: nil, trailingClipID: nil)
        }

        editorState?.addTransition(transition)
    }
}
