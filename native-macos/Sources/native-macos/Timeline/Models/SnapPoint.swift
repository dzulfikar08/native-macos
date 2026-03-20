import Foundation
import CoreMedia

/// The type of snap point for positioning clips on the timeline.
/// Snap points are reference locations that clips can magnetically align to during drag operations.
enum SnapPointType: Equatable {
    /// Start or end of another clip on the timeline
    case clipEdge
    /// Track boundary (start of track at time zero)
    case trackBoundary
    /// Current playhead position
    case playhead
    /// Regular time interval (e.g., every second)
    case timeIncrement
    /// Chapter marker position
    case marker
}

/// A point on the timeline where a clip can snap to during drag operations.
/// Snap points provide visual and magnetic feedback to help users align clips precisely.
struct SnapPoint: Equatable {
    /// The position in timeline time where the snap occurs
    let position: CMTime
    /// The type of snap point (determines visual indicator)
    let type: SnapPointType
    /// Optional description (e.g., "Clip 'Intro' start") for debugging and accessibility
    let source: String?

    init(position: CMTime, type: SnapPointType, source: String? = nil) {
        // Validate CMTime is valid and non-negative
        precondition(position.isValid, "SnapPoint position must be a valid CMTime")
        precondition(CMTimeGetSeconds(position) >= 0, "SnapPoint position must be non-negative")

        self.position = position
        self.type = type
        self.source = source
    }
}
