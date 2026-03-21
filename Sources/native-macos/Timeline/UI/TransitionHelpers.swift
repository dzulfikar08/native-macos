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
