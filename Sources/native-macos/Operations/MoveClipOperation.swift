import Foundation
import CoreMedia

/// Moves a clip to a new position and/or track
final class MoveClipOperation: BaseClipOperation {
    private let clipID: UUID
    private let newRange: CMTimeRange
    private let newTrackID: UUID
    private let ripple: Bool

    // State captured before modification
    private let originalTrackID: UUID
    private let originalRange: CMTimeRange

    init(clipID: UUID, newRange: CMTimeRange, newTrackID: UUID, ripple: Bool, editorState: EditorState, clipManager: ClipManager) {
        self.clipID = clipID
        self.newRange = newRange
        self.newTrackID = newTrackID
        self.ripple = ripple

        // Capture state before modification
        guard let clip = clipManager.findClip(id: clipID) else {
            fatalError("Clip not found during operation initialization")
        }

        self.originalTrackID = clip.trackID
        self.originalRange = clip.timeRangeInTimeline

        let oldDuration = CMTimeGetSeconds(clip.timelineDuration)
        let newDuration = CMTimeGetSeconds(newRange.duration)
        let oldTrackName = clipManager.findTrack(id: originalTrackID)?.name ?? "Unknown"
        let newTrackName = clipManager.findTrack(id: newTrackID)?.name ?? "Unknown"

        super.init(
            description: "Move Clip: \(clip.name) from Track \(oldTrackName) at \(oldDuration)s to Track \(newTrackName) at \(newDuration)s",
            editorState: editorState,
            clipManager: clipManager
        )
    }

    override func execute() throws {
        try clipManager?.moveClip(clipID: clipID, to: newRange, on: newTrackID, ripple: ripple)
    }

    override func undo() throws {
        guard let clipManager = clipManager else {
            throw UndoError.invalidState
        }

        guard let clip = clipManager.findClip(id: clipID) else {
            throw ClipError.clipNotFound
        }

        // Move back to original position and track
        clip.timeRangeInTimeline = originalRange
        clip.trackID = originalTrackID

        // Post notification
        NotificationCenter.default.post(
            name: .clipDidMove,
            object: self,
            userInfo: ["clip": clip]
        )
    }

    override func redo() throws {
        try execute()
    }
}