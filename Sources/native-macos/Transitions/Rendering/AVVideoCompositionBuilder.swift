import AVFoundation
import CoreMedia
import CoreVideo

/// Builds AVVideoComposition from timeline state for rendering transitions
@MainActor
final class AVVideoCompositionBuilder {

    /// Builds a video composition for the editor state
    /// - Parameter editorState: The editor state containing clips and transitions
    /// - Returns: Configured video composition, or nil if no video tracks
    func buildComposition(for editorState: EditorState) throws -> AVVideoComposition? {
        // Get video tracks only
        let videoTracks = editorState.clipTracks.filter { $0.type == .video }
        guard !videoTracks.isEmpty else {
            return nil
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
                let transitionInstruction = try buildTransitionInstruction(
                    transition: transition,
                    leadingClip: clip,
                    editorState: editorState
                )
                instructions.append(transitionInstruction)
            }
        }

        // Remove overlaps and sort
        instructions = mergeOverlappingInstructions(instructions)
        instructions.sort { $0.timeRange.start < $1.timeRange.start }

        let composition = AVMutableVideoComposition()
        composition.instructions = instructions
        composition.renderSize = renderSize(for: editorState)
        composition.frameDuration = detectFrameRate(for: editorState)

        return composition
    }

    /// Builds instruction for a transition
    private func buildTransitionInstruction(
        transition: TransitionClip,
        leadingClip: VideoClip,
        editorState: EditorState
    ) throws -> AVVideoCompositionInstruction {

        guard let trailingClip = editorState.clipTracks
            .flatMap({ $0.clips })
            .first(where: { $0.id == transition.trailingClipID }) else {
            throw TransitionError.clipsNotFound(
                leadingClipID: nil,
                trailingClipID: transition.trailingClipID
            )
        }

        // Calculate transition time range
        let transitionStart = trailingClip.timeRangeInTimeline.start
        let transitionEnd = CMTimeAdd(transitionStart, transition.duration)
        let timeRange = CMTimeRange(start: transitionStart, end: transitionEnd)

        // Create instruction
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = timeRange
        instruction.enablePostProcessing = true

        // Note: Layer instructions would be added here when we have actual AVAssetTracks
        // For now, we create the instruction with just the time range
        // In a full implementation, we would:
        // 1. Get the AVAssetTracks from the composition
        // 2. Create AVMutableVideoCompositionLayerInstruction for each track
        // 3. Set opacity ramps for cross-dissolve effect

        return instruction
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
