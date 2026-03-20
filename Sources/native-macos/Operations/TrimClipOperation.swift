import Foundation
import CoreMedia

/// Trims a clip to a new time range
final class TrimClipOperation: BaseClipOperation {
    private let clipID: UUID
    private let newRange: CMTimeRange

    // State captured before modification
    private let originalTimeRangeInSource: CMTimeRange
    private let originalTimeRangeInTimeline: CMTimeRange

    init(clipID: UUID, newRange: CMTimeRange, editorState: EditorState, clipManager: ClipManager) {
        self.clipID = clipID
        self.newRange = newRange

        // Capture state
        guard let clip = clipManager.findClip(id: clipID) else {
            fatalError("Clip not found during operation initialization")
        }

        self.originalTimeRangeInSource = clip.timeRangeInSource
        self.originalTimeRangeInTimeline = clip.timeRangeInTimeline

        let oldDuration = CMTimeGetSeconds(clip.timelineDuration)
        let newDuration = CMTimeGetSeconds(newRange.duration)

        super.init(
            description: "Trim Clip: \(clip.name) from \(oldDuration)s to \(newDuration)s",
            editorState: editorState,
            clipManager: clipManager
        )
    }

    override func execute() throws {
        try clipManager?.trimClip(clipID: clipID, to: newRange)
    }

    override func undo() throws {
        guard let clip = clipManager?.findClip(id: clipID) else {
            throw ClipError.clipNotFound
        }

        // Restore original ranges
        clip.timeRangeInSource = originalTimeRangeInSource
        clip.timeRangeInTimeline = originalTimeRangeInTimeline
    }

    override func redo() throws {
        try execute()
    }
}
