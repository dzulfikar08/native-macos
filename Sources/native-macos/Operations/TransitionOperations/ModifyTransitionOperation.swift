import Foundation
import CoreMedia
import AVFoundation

/// Modifies a transition's properties
final class ModifyTransitionOperation: BaseClipOperation {
    private let transitionID: UUID
    private let newType: TransitionType?
    private let newDuration: CMTime?
    private let newParameters: TransitionParameters?

    // Captured state for undo
    private var previousState: TransitionClip?

    init(
        transitionID: UUID,
        newType: TransitionType? = nil,
        newDuration: CMTime? = nil,
        newParameters: TransitionParameters? = nil,
        editorState: EditorState
    ) {
        self.transitionID = transitionID
        self.newType = newType
        self.newDuration = newDuration
        self.newParameters = newParameters

        let descriptionParts: [String] = [
            newType != nil ? "type" : nil,
            newDuration != nil ? "duration" : nil,
            newParameters != nil ? "parameters" : nil
        ].compactMap { $0 }

        super.init(
            description: "Modify transition (\(descriptionParts.joined(separator: ", ")))",
            editorState: editorState,
            clipManager: nil
        )
    }

    override func execute() throws {
        guard let editorState = editorState else {
            throw TransitionError.clipsNotFound(leadingClipID: nil, trailingClipID: nil)
        }

        // Find and capture current state
        guard let currentTransition = editorState.transitions.first(where: { $0.id == transitionID }) else {
            throw TransitionError.clipsNotFound(leadingClipID: nil, trailingClipID: nil)
        }

        previousState = currentTransition

        // Validate new duration if changing
        if let newDuration = newDuration {
            let overlap = editorState.calculateOverlap(
                between: currentTransition.leadingClipID,
                and: currentTransition.trailingClipID
            )

            if newDuration > overlap.duration {
                throw TransitionError.insufficientOverlap(
                    minimumRequired: newDuration,
                    available: overlap.duration
                )
            }
        }

        // Apply modifications
        var modified = currentTransition

        if let newType = newType {
            modified = modified.withType(newType)
        }

        if let newDuration = newDuration {
            modified = modified.withDuration(newDuration)
        }

        if let newParameters = newParameters {
            modified = modified.withParameters(newParameters)
        }

        // Update in editor state
        editorState.updateTransition(modified)
    }

    override func undo() throws {
        guard let previous = previousState else {
            throw TransitionError.clipsNotFound(leadingClipID: nil, trailingClipID: nil)
        }

        editorState?.updateTransition(previous)
    }
}
