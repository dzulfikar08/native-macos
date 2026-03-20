import Foundation
import CoreMedia

/// Time formatting utilities for OpenScreen
enum TimeUtils {
    /// Formats a CMTime value as a readable string (HH:MM:SS)
    static func formatTime(_ time: CMTime) -> String {
        guard time.isNumeric else { return "00:00" }

        let totalSeconds = CMTimeGetSeconds(time)
        return formatTimeInterval(totalSeconds)
    }

    /// Formats a time interval as HH:MM:SS
    static func formatTimeInterval(_ interval: Double) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) / 60 % 60
        let seconds = Int(interval) % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    /// Formats a duration as a human-readable string
    /// Note: For hour+ durations, seconds are omitted for brevity (e.g., "2h 15m")
    static func formatDuration(_ time: CMTime) -> String {
        let seconds = CMTimeGetSeconds(time)
        if seconds < 60 {
            return "\(Int(seconds))s"
        } else if seconds < 3600 {
            let minutes = Int(seconds / 60)
            let remainingSeconds = Int(seconds) % 60
            return "\(minutes)m \(remainingSeconds)s"
        } else {
            let hours = Int(seconds / 3600)
            let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(minutes)m"
        }
    }
}
