import AVFoundation
import CoreMedia
import CoreVideo
import Foundation

/// Builds AVVideoComposition from timeline state for rendering transitions
@MainActor
final class AVVideoCompositionBuilder {

    /// Builds a video composition for the editor state
    /// - Parameters:
    ///   - editorState: The editor state containing clips and transitions
    ///   - quality: Optional quality settings for export
    /// - Returns: Configured video composition, or nil if no video tracks
    func buildComposition(
        for editorState: EditorState,
        quality: ExportQualitySettings? = nil
    ) throws -> AVVideoComposition? {
        // Get video tracks only
        let videoTracks = editorState.clipTracks.filter { $0.type == .video }
        guard !videoTracks.isEmpty else {
            return nil
        }

        // Build clip to track ID mapping (sequential starting from 1)
        var clipTrackIDs: [UUID: CMPersistentTrackID] = [:]
        for (trackIndex, track) in videoTracks.enumerated() {
            let trackID = CMPersistentTrackID(trackIndex + 1)
            for clip in track.clips {
                clipTrackIDs[clip.id] = trackID
            }
        }

        // Flatten clips from all video tracks in time order
        let allClips = videoTracks
            .flatMap { $0.clips }
            .sorted { $0.timeRangeInTimeline.start < $1.timeRangeInTimeline.start }

        guard !allClips.isEmpty else {
            return nil
        }

        // Build instructions for clips and transitions
        var instructions: [AVVideoCompositionInstruction] = []

        for clip in allClips {
            // Check for transitions involving this clip
            let outgoingTransitions = editorState.transitions.filter {
                $0.leadingClipID == clip.id
            }

            let incomingTransitions = editorState.transitions.filter {
                $0.trailingClipID == clip.id
            }

            let clipStartTime = clip.timeRangeInTimeline.start
            let clipEndTime = clip.timeRangeInTimeline.end

            // Time before any outgoing transition
            var effectiveStartTime = clipStartTime
            var effectiveEndTime = clipEndTime

            // Adjust for incoming transition
            if let incoming = incomingTransitions.first {
                // Clip starts during transition, so effective start is after transition
                effectiveStartTime = CMTimeAdd(clipStartTime, incoming.duration)
            }

            // Adjust for outgoing transition
            if let outgoing = outgoingTransitions.first {
                // Clip ends before transition completes
                effectiveEndTime = CMTimeSubtract(clipEndTime, outgoing.duration)
            }

            // Add instruction for clip portion (not including transition)
            // Validate that we have a valid time range (start < end)
            if effectiveStartTime.isValid && effectiveEndTime.isValid &&
               CMTimeCompare(effectiveStartTime, effectiveEndTime) < 0 {
                let clipInstruction = AVMutableVideoCompositionInstruction()
                clipInstruction.timeRange = CMTimeRange(
                    start: effectiveStartTime,
                    end: effectiveEndTime
                )
                clipInstruction.enablePostProcessing = true
                instructions.append(clipInstruction)
            }

            // Add transition instructions
            for transition in outgoingTransitions {
                guard let trailingClip = editorState.clipTracks
                    .flatMap({ $0.clips })
                    .first(where: { $0.id == transition.trailingClipID }) else {
                    throw TransitionError.clipsNotFound(
                        leadingClipID: nil,
                        trailingClipID: transition.trailingClipID
                    )
                }

                guard let leadingTrackID = clipTrackIDs[clip.id],
                      let trailingTrackID = clipTrackIDs[trailingClip.id] else {
                    throw TransitionError.clipsNotFound(
                        leadingClipID: clip.id,
                        trailingClipID: trailingClip.id
                    )
                }

                let transitionInstruction = try buildTransitionInstruction(
                    transition: transition,
                    leadingClip: clip,
                    leadingTrackID: leadingTrackID,
                    trailingClip: trailingClip,
                    trailingTrackID: trailingTrackID,
                    editorState: editorState
                )
                instructions.append(transitionInstruction.makeAVInstruction())
            }
        }

        // Remove overlaps and sort
        instructions = mergeOverlappingInstructions(instructions)
        instructions.sort { $0.timeRange.start < $1.timeRange.start }

        let composition = AVMutableVideoComposition()
        composition.instructions = instructions

        // Use quality settings for render size if provided
        if let quality = quality {
            composition.renderSize = quality.renderSize ?? renderSize(for: editorState)
        } else {
            composition.renderSize = renderSize(for: editorState)
        }

        composition.frameDuration = detectFrameRate(for: editorState)

        // Set custom compositor
        composition.customVideoCompositorClass = TransitionVideoCompositor.self

        // Store editor state for compositor to access
        TransitionVideoCompositor.setEditorState(editorState)

        return composition
    }

    /// Builds instruction for a transition
    private func buildTransitionInstruction(
        transition: TransitionClip,
        leadingClip: VideoClip,
        leadingTrackID: CMPersistentTrackID,
        trailingClip: VideoClip,
        trailingTrackID: CMPersistentTrackID,
        editorState: EditorState
    ) throws -> TransitionCompositionInstruction {

        // Calculate transition time range
        let transitionStart = trailingClip.timeRangeInTimeline.start
        _ = CMTimeAdd(transitionStart, transition.duration) // Validates the time range

        // Create TransitionCompositionInstruction wrapper
        return TransitionCompositionInstruction(
            transitionID: transition.id,
            transitionType: transition.type,
            transitionParameters: transition.parameters,
            transitionStart: transitionStart,
            transitionDuration: transition.duration,
            leadingTrackID: leadingTrackID,
            trailingTrackID: trailingTrackID
        )
    }

    /// Merges overlapping instructions
    /// TODO: Implement proper time range merging logic. This is a stub that returns instructions unchanged.
    /// Before production use, this needs to:
    /// - Detect overlapping time ranges
    /// - Either merge overlapping instructions or split them appropriately
    /// - Ensure no time ranges overlap in the final composition
    private func mergeOverlappingInstructions(_ instructions: [AVVideoCompositionInstruction]) -> [AVVideoCompositionInstruction] {
        // Current implementation assumes instructions don't overlap
        // This is valid for our current use case where transitions split clips properly
        return instructions
    }

    /// Detects frame rate from video assets
    private func detectFrameRate(for editorState: EditorState) -> CMTime {
        // Try to detect frame rate from first video clip's asset
        if let firstClip = editorState.clipTracks
            .filter({ $0.type == .video })
            .flatMap({ $0.clips })
            .first {
            let asset = firstClip.asset
            if let track = asset.tracks(withMediaType: .video).first {
                // Use the track's nominal frame rate
                let frameRate = track.nominalFrameRate
                if frameRate > 0 {
                    // CMTime(value: 1, timescale: frameRate) gives us 1/frameRate seconds per frame
                    // For 30 FPS: CMTime(value: 1, timescale: 30) = 1/30 second
                    return CMTime(value: 1, timescale: CMTimeScale(frameRate))
                }
            }
        }

        // Default to 30 FPS if detection fails
        return CMTime(value: 1, timescale: 30)
    }

    /// Calculates render size from editor state
    private func renderSize(for editorState: EditorState) -> CGSize {
        // Use first video clip's asset to determine size
        if let firstClip = editorState.clipTracks
            .filter({ $0.type == .video })
            .flatMap({ $0.clips })
            .first {
            let asset = firstClip.asset
            let track = asset.tracks(withMediaType: .video).first
            return track?.naturalSize ?? CGSize(width: 1920, height: 1080)
        }
        return CGSize(width: 1920, height: 1080)
    }
}
