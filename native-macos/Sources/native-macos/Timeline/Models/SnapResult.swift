import Foundation
import CoreMedia

/// Result of a snap calculation showing where a clip should snap.
/// Contains both the snap point found and the offset needed to reach it.
struct SnapResult {
    /// The snap point that was found
    let snapPoint: SnapPoint
    /// The original position before snapping
    let originalPosition: CMTime
    /// The snapped position (after applying snap offset)
    let snappedPosition: CMTime
    /// The offset between original and snapped position (snapped - original)
    let offset: CMTime

    init(snapPoint: SnapPoint, originalPosition: CMTime, snappedPosition: CMTime) {
        // Validate all CMTime values
        precondition(originalPosition.isValid, "Original position must be valid CMTime")
        precondition(snappedPosition.isValid, "Snapped position must be valid CMTime")

        self.snapPoint = snapPoint
        self.originalPosition = originalPosition
        self.snappedPosition = snappedPosition

        // Calculate offset, handle CMTime subtraction errors
        let calculatedOffset = CMTimeSubtract(snappedPosition, originalPosition)
        precondition(calculatedOffset.isValid, "Offset calculation resulted in invalid CMTime")
        self.offset = calculatedOffset
    }

    /// The magnitude of the snap offset in seconds (can be negative)
    var offsetSeconds: Double {
        return CMTimeGetSeconds(offset)
    }

    /// Whether the snap offset is within the specified tolerance
    func isWithinTolerance(_ tolerance: TimeInterval) -> Bool {
        return abs(offsetSeconds) <= tolerance
    }
}
