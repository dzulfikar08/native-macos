import Foundation
import AVFoundation
import CoreMedia

/// Duplicates a clip to a new position
final class DuplicateClipOperation: BaseClipOperation {
    private let clipID: UUID
    private let newRange: CMTimeRange
    private let originalClipCount: Int

    // State captured after execution
    private var duplicatedClipID: UUID?

    init(clipID: UUID, newRange: CMTimeRange, editorState: EditorState, clipManager: ClipManager) {
        self.clipID = clipID
        self.newRange = newRange

        // Capture original clip count
        guard let clip = clipManager.findClip(id: clipID),
              let track = clipManager.findTrack(id: clip.trackID) else {
            fatalError("Clip not found during operation initialization")
        }

        self.originalClipCount = track.clips.count

        let originalDuration = CMTimeGetSeconds(clip.timelineDuration)
        let newDuration = CMTimeGetSeconds(newRange.duration)
        let trackName = track.name

        super.init(
            description: "Duplicate Clip: \(clip.name) from track \(trackName) (\(originalDuration)s → \(newDuration)s)",
            editorState: editorState,
            clipManager: clipManager
        )
    }

    override func execute() throws {
        // Duplicate the clip and find the duplicate to get its ID
        try clipManager?.duplicateClip(clipID: clipID, to: newRange)

        // Find the newly created duplicate clip
        guard let track = clipManager?.findTrack(id: clipID) else {
            throw ClipError.clipNotFound
        }

        duplicatedClipID = track.clips.first { $0.name.contains("copy") && $0.id != clipID }?.id
    }

    override func undo() throws {
        guard let clipManager = clipManager else {
            throw UndoError.invalidState
        }

        guard let duplicatedClipID = duplicatedClipID else {
            throw UndoError.invalidState
        }

        guard let track = clipManager.findTrack(id: duplicatedClipID) else {
            throw ClipError.trackNotFound
        }

        // Remove the duplicated clip
        track.removeClip(id: duplicatedClipID)

        // Post notification
        NotificationCenter.default.post(
            name: .clipDidDelete,
            object: self,
            userInfo: ["clipID": duplicatedClipID]
        )
    }

    override func redo() throws {
        // Recreate the duplicate and find it
        try clipManager?.duplicateClip(clipID: clipID, to: newRange)

        // Find the newly created duplicate clip
        guard let track = clipManager?.findTrack(id: clipID) else {
            throw ClipError.clipNotFound
        }

        duplicatedClipID = track.clips.first { $0.name.contains("copy") && $0.id != clipID }?.id
    }
}