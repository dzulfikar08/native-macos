import Foundation
import AVFoundation
import CoreMedia

/// Changes the playback speed of a clip
final class ChangeSpeedOperation: BaseClipOperation {
    private let clipID: UUID
    private let newSpeed: Float
    private let originalSpeed: Float
    private let originalTimelineDuration: CMTime

    init(clipID: UUID, newSpeed: Float, editorState: EditorState, clipManager: ClipManager) {
        self.clipID = clipID
        self.newSpeed = newSpeed

        // Capture state before modification
        guard let clip = clipManager.findClip(id: clipID) else {
            fatalError("Clip not found during operation initialization")
        }

        self.originalSpeed = clip.speed
        self.originalTimelineDuration = clip.timelineDuration

        let oldDuration = CMTimeGetSeconds(clip.timelineDuration)
        let newDuration = CMTimeGetSeconds(clip.timelineDuration) / Double(newSpeed / originalSpeed)

        super.init(
            description: "Change Speed: \(clip.name) from \(originalSpeed)x to \(newSpeed)x (\(oldDuration)s → \(newDuration)s)",
            editorState: editorState,
            clipManager: clipManager
        )
    }

    override func execute() throws {
        try clipManager?.changeClipSpeed(clipID: clipID, to: newSpeed)
    }

    override func undo() throws {
        guard let clip = clipManager?.findClip(id: clipID) else {
            throw ClipError.clipNotFound
        }

        // Restore original speed
        clip.speed = originalSpeed

        // Restore original timeline duration
        clip.timeRangeInTimeline = CMTimeRange(
            start: clip.timeRangeInTimeline.start,
            duration: originalTimelineDuration
        )

        // Post notification
        NotificationCenter.default.post(
            name: .clipDidChangeSpeed,
            object: self,
            userInfo: ["clip": clip, "oldSpeed": originalSpeed]
        )
    }

    override func redo() throws {
        try execute()
    }
}