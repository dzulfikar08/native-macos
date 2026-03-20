import Foundation
import CoreMedia

/// Represents the overlap between two adjacent clips
struct ClipOverlap: Identifiable, Sendable {
    let id: UUID = UUID()
    let leadingClip: VideoClip
    let trailingClip: VideoClip
    let overlapDuration: CMTime
    let overlapRange: ClosedRange<CMTime>

    /// The time range where the overlap occurs
    var timeRange: CMTimeRange {
        return CMTimeRange(
            start: overlapRange.lowerBound,
            end: overlapRange.upperBound
        )
    }

    /// Center point of the overlap
    var centerPoint: CMTime {
        let startSeconds = CMTimeGetSeconds(overlapRange.lowerBound)
        let endSeconds = CMTimeGetSeconds(overlapRange.upperBound)
        return CMTime(
            seconds: (startSeconds + endSeconds) / 2.0,
            preferredTimescale: 600
        )
    }
}

/// Detects overlapping clips in a timeline
struct ClipOverlapDetector {
    /// Finds all overlapping adjacent clips
    /// - Parameter clips: Array of clips to analyze (should be on same track)
    /// - Returns: Array of detected overlaps
    @MainActor
    func detectOverlaps(clips: [VideoClip]) -> [ClipOverlap] {
        guard clips.count >= 2 else {
            return []
        }

        var overlaps: [ClipOverlap] = []

        // Check adjacent clips for overlap
        for i in 0..<(clips.count - 1) {
            let leading = clips[i]
            let trailing = clips[i + 1]

            if let overlap = calculateOverlap(between: leading, and: trailing) {
                overlaps.append(overlap)
            }
        }

        return overlaps
    }

    /// Calculates overlap between two clips
    @MainActor
    private func calculateOverlap(between leading: VideoClip, and trailing: VideoClip) -> ClipOverlap? {
        let leadingEnd = leading.timeRangeInTimeline.end
        let trailingStart = trailing.timeRangeInTimeline.start

        // Overlap exists if leading clip ends after trailing clip starts
        guard leadingEnd > trailingStart else {
            return nil
        }

        let overlapDuration = CMTimeSubtract(leadingEnd, trailingStart)
        let overlapRange = trailingStart...leadingEnd

        return ClipOverlap(
            leadingClip: leading,
            trailingClip: trailing,
            overlapDuration: overlapDuration,
            overlapRange: overlapRange
        )
    }

    /// Finds overlap between two specific clips
    @MainActor
    func findOverlap(between clipID1: UUID, and clipID2: UUID, in clips: [VideoClip]) -> ClipOverlap? {
        guard
            let clip1 = clips.first(where: { $0.id == clipID1 }),
            let clip2 = clips.first(where: { $0.id == clipID2 })
        else {
            return nil
        }

        // Determine which is leading and which is trailing
        let leading: VideoClip
        let trailing: VideoClip

        if clip1.timeRangeInTimeline.start < clip2.timeRangeInTimeline.start {
            leading = clip1
            trailing = clip2
        } else {
            leading = clip2
            trailing = clip1
        }

        return calculateOverlap(between: leading, and: trailing)
    }
}

/// Validates transitions against constraints
struct TransitionValidator {
    /// Minimum transition duration (0.1 seconds)
    static let minimumDuration: CMTime = CMTime(seconds: 0.1, preferredTimescale: 600)

    /// Validates a transition against available overlap
    /// - Parameters:
    ///   - transition: The transition to validate
    ///   - availableOverlap: The available overlap duration
    /// - Throws: TransitionError if validation fails
    func validate(_ transition: TransitionClip, availableOverlap: CMTime) throws {
        // Validate internal consistency
        guard transition.isValid else {
            throw TransitionError.invalidParameters(reason: "Transition has invalid parameters or duration")
        }

        // Validate minimum duration
        guard transition.duration >= Self.minimumDuration else {
            throw TransitionError.parameterOutOfRange(
                "duration",
                validRange: CMTimeGetSeconds(Self.minimumDuration)...Double.greatestFiniteMagnitude
            )
        }

        // Validate duration doesn't exceed overlap
        guard transition.duration <= availableOverlap else {
            throw TransitionError.durationExceedsOverlap(
                available: availableOverlap,
                requested: transition.duration
            )
        }
    }

    /// Validates transition can be added between two clips
    /// - Parameters:
    ///   - transition: The transition to validate
    ///   - leadingClip: The clip before the transition
    ///   - trailingClip: The clip after the transition
    ///   - existingTransitions: Current transitions to check for overlap
    /// - Throws: TransitionError if validation fails
    @MainActor
    func validate(
        _ transition: TransitionClip,
        leadingClip: VideoClip,
        trailingClip: VideoClip,
        existingTransitions: [TransitionClip]
    ) throws {
        // Calculate overlap
        guard let overlap = calculateOverlap(between: leadingClip, and: trailingClip) else {
            throw TransitionError.insufficientOverlap(
                minimumRequired: transition.duration,
                available: .zero
            )
        }

        // Validate against overlap duration
        try validate(transition, availableOverlap: overlap.overlapDuration)

        // Check for conflicts with existing transitions
        for existing in existingTransitions {
            if transitionsOverlap(transition, existing) {
                throw TransitionError.transitionOverlap(existing.id)
            }
        }
    }

    /// Checks if two transitions would overlap
    private func transitionsOverlap(_ transition1: TransitionClip, _ transition2: TransitionClip) -> Bool {
        // Transitions overlap if they share a clip
        return transition1.leadingClipID == transition2.leadingClipID ||
               transition1.leadingClipID == transition2.trailingClipID ||
               transition1.trailingClipID == transition2.leadingClipID ||
               transition1.trailingClipID == transition2.trailingClipID
    }

    /// Calculates overlap between two clips
    @MainActor
    private func calculateOverlap(between leading: VideoClip, and trailing: VideoClip) -> ClipOverlap? {
        let leadingEnd = leading.timeRangeInTimeline.end
        let trailingStart = trailing.timeRangeInTimeline.start

        guard leadingEnd > trailingStart else {
            return nil
        }

        let overlapDuration = CMTimeSubtract(leadingEnd, trailingStart)

        return ClipOverlap(
            leadingClip: leading,
            trailingClip: trailing,
            overlapDuration: overlapDuration,
            overlapRange: trailingStart...leadingEnd
        )
    }
}
