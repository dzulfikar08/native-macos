import Foundation
import AVFoundation
import CoreMedia

/// Manages video clips on the timeline
/// Note: Not Sendable due to AVAsset. All access must remain on @MainActor.
@MainActor
class ClipManager: ObservableObject {
    private weak var editorState: EditorState?

    init(editorState: EditorState) {
        self.editorState = editorState
    }

    // MARK: - Find Operations

    /// Find a clip by ID across all tracks
    func findClip(id: UUID) -> VideoClip? {
        guard let editorState = editorState else { return nil }
        for track in editorState.clipTracks {
            if let clip = track.clips.first(where: { $0.id == id }) {
                return clip
            }
        }
        return nil
    }

    /// Find a track by ID
    func findTrack(id: UUID) -> ClipTrack? {
        guard let editorState = editorState else { return nil }
        return editorState.clipTracks.first(where: { $0.id == id })
    }

    // MARK: - Split Clip

    /// Split a clip at a specific time point
    /// - Parameters:
    ///   - clipID: The ID of the clip to split
    ///   - splitTime: The time in the timeline where the split should occur
    /// - Throws: ClipError if clip is not found or split point is invalid
    func splitClip(clipID: UUID, at splitTime: CMTime) throws {
        guard let clip = findClip(id: clipID) else {
            throw ClipError.clipNotFound
        }

        guard let track = findTrack(id: clip.trackID) else {
            throw ClipError.trackNotFound
        }

        // Validate split point is within clip and not at boundaries
        let clipRange = clip.timeRangeInTimeline
        guard splitTime > clipRange.start && splitTime < clipRange.end else {
            throw ClipError.invalidSplitPoint
        }

        // Calculate split offsets
        let splitOffset = clip.timelineTimeInSource(splitTime)
        let leftDuration = splitTime - clipRange.start
        let rightDuration = clipRange.end - splitTime

        // Create left clip
        let leftClip = VideoClip(
            name: "\(clip.name) (L)",
            asset: clip.asset,
            timeRangeInSource: CMTimeRange(
                start: clip.timeRangeInSource.start,
                end: splitOffset
            ),
            timeRangeInTimeline: CMTimeRange(
                start: clipRange.start,
                duration: leftDuration
            ),
            trackID: clip.trackID,
            opacity: clip.opacity,
            speed: clip.speed,
            volume: clip.volume
        )

        // Create right clip
        let rightClip = VideoClip(
            name: "\(clip.name) (R)",
            asset: clip.asset,
            timeRangeInSource: CMTimeRange(
                start: splitOffset,
                end: clip.timeRangeInSource.end
            ),
            timeRangeInTimeline: CMTimeRange(
                start: splitTime,
                duration: rightDuration
            ),
            trackID: clip.trackID,
            opacity: clip.opacity,
            speed: clip.speed,
            volume: clip.volume
        )

        // Remove original clip and add new clips
        track.removeClip(id: clipID)
        track.addClip(leftClip)
        track.addClip(rightClip)

        // Post notification
        NotificationCenter.default.post(
            name: .clipDidSplit,
            object: self,
            userInfo: ["leftClip": leftClip, "rightClip": rightClip]
        )
    }

    // MARK: - Trim Clip

    /// Trim a clip to a new time range
    /// - Parameters:
    ///   - clipID: The ID of the clip to trim
    ///   - newRange: The new time range in the timeline
    /// - Throws: ClipError if clip is not found or trim exceeds source
    func trimClip(clipID: UUID, to newRange: CMTimeRange) throws {
        guard let clip = findClip(id: clipID) else {
            throw ClipError.clipNotFound
        }

        // Validate new range doesn't exceed source duration
        let sourceDuration = clip.timeRangeInSource.duration
        let speed = clip.speed
        let maxTimelineDuration = CMTimeMultiplyByFloat64(sourceDuration, multiplier: Float64(1.0 / speed))

        if newRange.duration > maxTimelineDuration {
            throw ClipError.trimExceedsSource
        }

        // Calculate proportional source range
        let startDelta = newRange.start - clip.timeRangeInTimeline.start
        let sourceStartDelta = CMTimeMultiplyByFloat64(startDelta, multiplier: Float64(speed))

        let newSourceStart = clip.timeRangeInSource.start + sourceStartDelta
        let newSourceDuration = CMTimeMultiplyByFloat64(newRange.duration, multiplier: Float64(speed))

        // Update clip
        clip.timeRangeInTimeline = newRange
        clip.timeRangeInSource = CMTimeRange(
            start: newSourceStart,
            duration: newSourceDuration
        )

        // Post notification
        NotificationCenter.default.post(
            name: .clipDidTrim,
            object: self,
            userInfo: ["clip": clip]
        )
    }

    // MARK: - Move Clip

    /// Move a clip to a new position on a track
    /// - Parameters:
    ///   - clipID: The ID of the clip to move
    ///   - newRange: The new time range in the timeline
    ///   - targetTrackID: The ID of the target track
    ///   - ripple: Whether to ripple subsequent clips
    /// - Throws: ClipError if clip is not found or would overlap
    func moveClip(clipID: UUID, to newRange: CMTimeRange, on targetTrackID: UUID, ripple: Bool) throws {
        guard let clip = findClip(id: clipID) else {
            throw ClipError.clipNotFound
        }

        guard let oldTrack = findTrack(id: clip.trackID) else {
            throw ClipError.trackNotFound
        }

        guard let newTrack = findTrack(id: targetTrackID) else {
            throw ClipError.trackNotFound
        }

        // Check for overlaps if not rippling
        if !ripple {
            let overlappingClips = newTrack.clips(in: newRange).filter { $0.id != clipID }
            if !overlappingClips.isEmpty {
                throw ClipError.wouldOverlap
            }
        }

        // Remove from old track
        oldTrack.removeClip(id: clipID)

        // If rippling, shift subsequent clips
        if ripple && oldTrack.id == newTrack.id {
            let gapStart = clip.timeRangeInTimeline.end
            let newEnd = newRange.end
            let durationDelta = newEnd - gapStart

            for var existingClip in oldTrack.clips where existingClip.timeRangeInTimeline.start >= gapStart {
                existingClip.timeRangeInTimeline = CMTimeRange(
                    start: existingClip.timeRangeInTimeline.start + durationDelta,
                    duration: existingClip.timeRangeInTimeline.duration
                )
            }
        }

        // Update clip and add to new track
        clip.timeRangeInTimeline = newRange
        clip.trackID = targetTrackID
        newTrack.addClip(clip)

        // Post notification
        NotificationCenter.default.post(
            name: .clipDidMove,
            object: self,
            userInfo: ["clip": clip]
        )
    }

    // MARK: - Delete Clip

    /// Delete a clip from its track
    /// - Parameters:
    ///   - clipID: The ID of the clip to delete
    ///   - ripple: Whether to ripple subsequent clips
    /// - Throws: ClipError if clip is not found
    func deleteClip(clipID: UUID, ripple: Bool) throws {
        guard let clip = findClip(id: clipID) else {
            throw ClipError.clipNotFound
        }

        guard let track = findTrack(id: clip.trackID) else {
            throw ClipError.trackNotFound
        }

        let gapDuration = clip.timeRangeInTimeline.duration

        // Remove clip
        track.removeClip(id: clipID)

        // If rippling, shift subsequent clips left
        if ripple {
            let gapStart = clip.timeRangeInTimeline.start
            for var existingClip in track.clips where existingClip.timeRangeInTimeline.start >= gapStart {
                existingClip.timeRangeInTimeline = CMTimeRange(
                    start: existingClip.timeRangeInTimeline.start - gapDuration,
                    duration: existingClip.timeRangeInTimeline.duration
                )
            }
        }

        // Post notification
        NotificationCenter.default.post(
            name: .clipDidDelete,
            object: self,
            userInfo: ["clipID": clipID]
        )
    }

    // MARK: - Duplicate Clip

    /// Duplicate a clip to a new position
    /// - Parameters:
    ///   - clipID: The ID of the clip to duplicate
    ///   - newRange: The time range for the duplicated clip
    /// - Throws: ClipError if clip is not found or would overlap
    func duplicateClip(clipID: UUID, to newRange: CMTimeRange) throws {
        guard let originalClip = findClip(id: clipID) else {
            throw ClipError.clipNotFound
        }

        guard let track = findTrack(id: originalClip.trackID) else {
            throw ClipError.trackNotFound
        }

        // Check for overlaps
        let overlappingClips = track.clips(in: newRange).filter { $0.id != clipID }
        if !overlappingClips.isEmpty {
            throw ClipError.wouldOverlap
        }

        // Create duplicate clip
        let duplicateClip = VideoClip(
            name: "\(originalClip.name) copy",
            asset: originalClip.asset,
            timeRangeInSource: originalClip.timeRangeInSource,
            timeRangeInTimeline: newRange,
            trackID: originalClip.trackID,
            opacity: originalClip.opacity,
            speed: originalClip.speed,
            volume: originalClip.volume
        )

        // Add to track
        track.addClip(duplicateClip)

        // Post notification
        NotificationCenter.default.post(
            name: .clipDidDuplicate,
            object: self,
            userInfo: ["originalClip": originalClip, "duplicateClip": duplicateClip]
        )
    }

    // MARK: - Change Clip Speed

    /// Change the playback speed of a clip
    /// - Parameters:
    ///   - clipID: The ID of the clip
    ///   - newSpeed: The new playback speed (0.1x to 16.0x)
    /// - Throws: ClipError if clip is not found or speed is invalid
    func changeClipSpeed(clipID: UUID, to newSpeed: Float) throws {
        guard let clip = findClip(id: clipID) else {
            throw ClipError.clipNotFound
        }

        // Validate speed range
        guard (0.1...16.0).contains(newSpeed) else {
            throw ClipError.invalidSpeed
        }

        // Store old speed before modification
        let oldSpeed = clip.speed

        // Update speed
        clip.speed = newSpeed

        // Recalculate timeline duration
        let newTimelineDuration = clip.timelineDuration

        // Adjust timeRangeInTimeline to maintain end point
        let endPoint = clip.timeRangeInTimeline.end
        clip.timeRangeInTimeline = CMTimeRange(
            start: endPoint - newTimelineDuration,
            duration: newTimelineDuration
        )

        // Post notification
        NotificationCenter.default.post(
            name: .clipDidChangeSpeed,
            object: self,
            userInfo: ["clip": clip, "oldSpeed": oldSpeed]
        )
    }
}
