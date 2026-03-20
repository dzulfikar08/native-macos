import Foundation
import CoreMedia
import AVFoundation

/// Creates a transition between two overlapping clips
final class CreateTransitionOperation: BaseClipOperation {
    private let transitionType: TransitionType
    private let duration: CMTime
    private let leadingClipID: UUID
    private let trailingClipID: UUID
    private var createdTransitionID: UUID?

    init(
        transitionType: TransitionType,
        duration: CMTime,
        leadingClipID: UUID,
        trailingClipID: UUID,
        editorState: EditorState
    ) {
        self.transitionType = transitionType
        self.duration = duration
        self.leadingClipID = leadingClipID
        self.trailingClipID = trailingClipID

        super.init(
            description: "Create \(transitionType) transition",
            editorState: editorState,
            clipManager: nil
        )
    }

    override func execute() throws {
        guard let editorState = editorState else {
            throw TransitionError.clipsNotFound(leadingClipID: nil, trailingClipID: nil)
        }

        // Find clips
        guard let leadingClip = editorState.clipTracks.flatMap({ $0.clips }).first(where: { $0.id == leadingClipID }),
              let trailingClip = editorState.clipTracks.flatMap({ $0.clips }).first(where: { $0.id == trailingClipID }) else {
            throw TransitionError.clipsNotFound(
                leadingClipID: editorState.clipTracks.flatMap({ $0.clips }).first(where: { $0.id == leadingClipID }) == nil ? leadingClipID : nil,
                trailingClipID: editorState.clipTracks.flatMap({ $0.clips }).first(where: { $0.id == trailingClipID }) == nil ? trailingClipID : nil
            )
        }

        // Validate overlap
        let overlap = editorState.calculateOverlap(
            between: leadingClip.id,
            and: trailingClip.id
        )

        guard overlap.duration >= duration else {
            throw TransitionError.insufficientOverlap(
                minimumRequired: duration,
                available: overlap.duration
            )
        }

        // Create transition
        let transition = TransitionClip(
            type: transitionType,
            duration: duration,
            leadingClipID: leadingClipID,
            trailingClipID: trailingClipID
        )

        // Store ID for undo
        createdTransitionID = transition.id

        // Add to editor state
        editorState.addTransition(transition)
    }

    override func undo() throws {
        guard let transitionID = createdTransitionID else {
            throw TransitionError.clipsNotFound(leadingClipID: nil, trailingClipID: nil)
        }

        editorState?.removeTransition(id: transitionID)
        createdTransitionID = nil
    }
}
