import AppKit
import Foundation
import CoreMedia

/// Formats CMTime as human-readable string
/// - Parameter time: The time to format
/// - Returns: String representation (e.g., "0.5s", "1:30")
func formatDuration(_ time: CMTime) -> String {
    let seconds = CMTimeGetSeconds(time)
    if seconds < 60 {
        return String(format: "%.1fs", seconds)
    } else {
        let minutes = Int(seconds) / 60
        let remainder = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainder)
    }
}

/// Shows alert message to user
/// - Parameter message: The message to display
func showAlert(message: String) {
    let alert = NSAlert()
    alert.messageText = message
    alert.alertStyle = .informational
    alert.addButton(withTitle: "OK")

    if let window = NSApp.keyWindow {
        alert.beginSheetModal(for: window)
    } else {
        alert.runModal()
    }
}

/// Calculates overlap between two clips
/// - Parameters:
///   - leading: The clip that appears first in timeline
///   - trailing: The clip that appears second in timeline
/// - Returns: The overlap duration, or .zero if no overlap
@MainActor
func calculateOverlap(leading: VideoClip, trailing: VideoClip) -> CMTime {
    let leadingEnd = leading.timeRangeInTimeline.end
    let trailingStart = trailing.timeRangeInTimeline.start

    // Overlap exists if leading clip ends after trailing clip starts
    guard leadingEnd > trailingStart else {
        return .zero
    }

    return max(CMTime(seconds: 0, preferredTimescale: 600), leadingEnd - trailingStart)
}

/// Finds the two clips that overlap at a given point in the timeline
/// - Parameters:
///   - point: Point in timeline coordinate space
///   - viewModel: TimelineViewModel containing clips
/// - Returns: Tuple of (leadingClip, trailingClip) if point is between two overlapping clips
///
/// TODO: This function requires the following TimelineViewModel methods:
/// - `selectedTrack` property (or equivalent)
/// - `time(at:)` method to convert CGPoint → CMTime
///
/// Once TimelineViewModel has these methods, implement as:
/// ```swift
/// func findClipsAt(point: CGPoint, in viewModel: TimelineViewModel) -> (VideoClip, VideoClip)? {
///     let timeAtPoint = viewModel.time(at: point)
///     guard let track = viewModel.selectedTrack else { return nil }
///
///     let clipsAtTime = track.clips.filter { clip in
///         timeAtPoint >= clip.timeRangeInTimeline.start &&
///         timeAtPoint <= clip.timeRangeInTimeline.end
///     }
///
///     guard clipsAtTime.count == 2 else { return nil }
///
///     let leadingClip = clipsAtTime.min(by: { $0.timeRangeInTimeline.start < $1.timeRangeInTimeline.start })
///     let trailingClip = clipsAtTime.max(by: { $0.timeRangeInTimeline.start < $1.timeRangeInTimeline.start })
///
///     guard let leading = leadingClip, let trailing = trailingClip else { return nil }
///
///     let overlapDuration = trailing.timeRangeInTimeline.end - leading.timeRangeInTimeline.start
///     guard overlapDuration >= TransitionValidator.minimumDuration else { return nil }
///
///     return (leading, trailing)
/// }
/// ```
func findClipsAt(point: CGPoint, in viewModel: TimelineViewModel) -> (VideoClip, VideoClip)? {
    // TODO: Implement once TimelineViewModel has time(at:) and selectedTrack
    // See documentation above for planned implementation
    return nil
}
