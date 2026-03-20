import Foundation
import AVFoundation
import CoreMedia

/// Deletes a clip from its track
final class DeleteClipOperation: BaseClipOperation {
    private let clipID: UUID
    private let ripple: Bool

    // State captured before modification (full snapshot)
    private let clipState: ClipStateSnapshot

    init(clipID: UUID, ripple: Bool, editorState: EditorState, clipManager: ClipManager) {
        self.clipID = clipID
        self.ripple = ripple

        // Capture state before modification
        guard let clip = clipManager.findClip(id: clipID),
              let track = clipManager.findTrack(id: clip.trackID) else {
            fatalError("Clip not found during operation initialization")
        }

        self.clipState = ClipStateSnapshot(
            clipID: clip.id,
            name: clip.name,
            trackID: clip.trackID,
            timeRangeInSource: clip.timeRangeInSource,
            timeRangeInTimeline: clip.timeRangeInTimeline,
            trackClipCount: track.clips.count,
            asset: clip.asset,
            opacity: clip.opacity,
            speed: clip.speed,
            volume: clip.volume
        )

        super.init(
            description: "Delete Clip: \(clip.name)",
            editorState: editorState,
            clipManager: clipManager
        )
    }

    override func execute() throws {
        try clipManager?.deleteClip(clipID: clipID, ripple: ripple)
    }

    override func undo() throws {
        guard let clipManager = clipManager else {
            throw UndoError.invalidState
        }

        guard let track = clipManager.findTrack(id: clipState.trackID) else {
            throw ClipError.trackNotFound
        }

        // Re-create clip from snapshot
        let restoredClip = VideoClip(
            id: clipState.clipID,
            name: clipState.name,
            asset: clipState.asset,
            timeRangeInSource: clipState.timeRangeInSource,
            timeRangeInTimeline: clipState.timeRangeInTimeline,
            trackID: clipState.trackID,
            opacity: clipState.opacity,
            speed: clipState.speed,
            volume: clipState.volume
        )

        track.addClip(restoredClip)

        // Post notification
        NotificationCenter.default.post(
            name: .clipDidDuplicate,
            object: self,
            userInfo: ["clip": restoredClip]
        )
    }

    override func redo() throws {
        try execute()
    }
}

// MARK: - State Snapshot

private struct ClipStateSnapshot {
    let clipID: UUID
    let name: String
    let trackID: UUID
    let timeRangeInSource: CMTimeRange
    let timeRangeInTimeline: CMTimeRange
    let trackClipCount: Int
    let asset: AVAsset
    let opacity: Float
    let speed: Float
    let volume: Float
}