import Foundation
import CoreGraphics
import CoreMedia

// MARK: - CMTimeRange Convenience Extension

extension CMTimeRange {
    /// A zero time range (start: 0, duration: 0)
    static var zero: CMTimeRange {
        return CMTimeRange(start: .zero, duration: .zero)
    }
}

/// Cached layout information for a clip on the timeline.
/// Used by ClipLayoutCache to avoid recalculating clip positions on every render.
struct ClipLayout {
    /// The clip identifier
    let clipID: UUID
    /// The calculated frame in timeline coordinates (x, y, width, height)
    let frame: CGRect
    /// The time range used for the calculation
    let timeRange: CMTimeRange
    /// Whether the layout needs recalculation (marked dirty when clip or track changes)
    var isDirty: Bool

    init(clipID: UUID, frame: CGRect, timeRange: CMTimeRange, isDirty: Bool = true) {
        // Validate inputs
        precondition(!clipID.uuidString.isEmpty, "clipID must not be nil UUID")
        precondition(frame.width >= 0, "Frame width must be non-negative")
        precondition(frame.height >= 0, "Frame height must be non-negative")
        precondition(timeRange.duration.isValid, "TimeRange duration must be valid")

        self.clipID = clipID
        self.frame = frame
        self.timeRange = timeRange
        self.isDirty = isDirty
    }

    /// The x-position of the clip on the timeline
    var x: CGFloat { frame.origin.x }

    /// The y-position of the clip (track position)
    var y: CGFloat { frame.origin.y }

    /// The width of the clip in pixels
    var width: CGFloat { frame.size.width }

    /// The height of the clip in pixels
    var height: CGFloat { frame.size.height }

    /// The start time of the clip in timeline coordinates
    var startTime: CMTime { timeRange.start }

    /// The duration of the clip
    var duration: CMTime { timeRange.duration }
}
