import Foundation
import AVFoundation
import CoreMedia

/// Splits a clip into two clips at a specified time point
final class SplitClipOperation: BaseClipOperation {
    private let clipID: UUID
    private let splitTime: CMTime

    // State captured before modification
    private let originalClipState: ClipStateSnapshot

    init(clipID: UUID, splitTime: CMTime, editorState: EditorState, clipManager: ClipManager) {
        self.clipID = clipID
        self.splitTime = splitTime

        // Capture state before modification
        guard let clip = clipManager.findClip(id: clipID),
              let track = clipManager.findTrack(id: clip.trackID) else {
            fatalError("Clip not found during operation initialization")
        }

        self.originalClipState = ClipStateSnapshot(
            clipID: clip.id,
            name: clip.name,
            trackID: clip.trackID,
            timeRangeInSource: clip.timeRangeInSource,
            timeRangeInTimeline: clip.timeRangeInTimeline,
            trackClipCount: track.clips.count,
            asset: clip.asset
        )

        super.init(
            description: "Split Clip: \(clip.name) at \(CMTimeGetSeconds(splitTime))s",
            editorState: editorState,
            clipManager: clipManager
        )
    }

    override func execute() throws {
        try clipManager?.splitClip(clipID: clipID, at: splitTime)
    }

    override func undo() throws {
        guard let clipManager = clipManager else {
            throw UndoError.invalidState
        }

        guard let track = clipManager.findTrack(id: originalClipState.trackID) else {
            throw ClipError.trackNotFound
        }

        // Remove both split clips (they have names with "(L)" and "(R)" suffixes)
        let leftClipName = "\(originalClipState.name) (L)"
        let rightClipName = "\(originalClipState.name) (R)"

        track.clips.removeAll { clip in
            clip.name == leftClipName || clip.name == rightClipName
        }

        // Re-create original clip
        let restoredClip = VideoClip(
            id: originalClipState.clipID,
            name: originalClipState.name,
            asset: originalClipState.asset,
            timeRangeInSource: originalClipState.timeRangeInSource,
            timeRangeInTimeline: originalClipState.timeRangeInTimeline,
            trackID: originalClipState.trackID
        )

        track.addClip(restoredClip)
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
}
