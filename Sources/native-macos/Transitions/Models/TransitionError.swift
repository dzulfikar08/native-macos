import Foundation
import CoreMedia

/// Errors that can occur during transition operations
enum TransitionError: LocalizedError, Equatable {
    /// Transition duration exceeds available clip overlap
    case durationExceedsOverlap(available: CMTime, requested: CMTime)

    /// Transition parameters are invalid
    case invalidParameters(reason: String)

    /// One or both clips referenced by transition not found
    case clipsNotFound(leadingClipID: UUID?, trailingClipID: UUID?)

    /// Insufficient overlap between clips to add transition
    case insufficientOverlap(minimumRequired: CMTime, available: CMTime)

    /// A specific parameter is out of valid range
    case parameterOutOfRange(String, validRange: ClosedRange<Double>)

    /// Transition would overlap with another transition
    case transitionOverlap(UUID)

    var errorDescription: String? {
        switch self {
        case .durationExceedsOverlap(let available, let requested):
            let availableSec = CMTimeGetSeconds(available)
            let requestedSec = CMTimeGetSeconds(requested)
            return "Transition duration (\(requestedSec)s) exceeds available clip overlap (\(availableSec)s)"

        case .invalidParameters(let reason):
            return "Invalid transition parameters: \(reason)"

        case .clipsNotFound(let leadingID, let trailingID):
            var missing: [String] = []
            if leadingID != nil { missing.append("leading clip") }
            if trailingID != nil { missing.append("trailing clip") }
            return "Clips not found: \(missing.joined(separator: ", "))"

        case .insufficientOverlap(let minimumRequired, let available):
            let minSec = CMTimeGetSeconds(minimumRequired)
            let availSec = CMTimeGetSeconds(available)
            return "Insufficient clip overlap: \(availSec)s available, \(minSec)s required"

        case .parameterOutOfRange(let param, let range):
            return "Parameter '\(param)' out of range: must be between \(range.lowerBound) and \(range.upperBound)"

        case .transitionOverlap(let id):
            return "Transition would overlap with existing transition (ID: \(id))"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .durationExceedsOverlap:
            return "Reduce transition duration or increase clip overlap"
        case .invalidParameters:
            return "Check transition parameters and try again"
        case .clipsNotFound:
            return "Ensure both clips exist in timeline"
        case .insufficientOverlap:
            return "Increase overlap between clips or use shorter transition"
        case .parameterOutOfRange(_, let range):
            return "Adjust parameter to be between \(range.lowerBound) and \(range.upperBound)"
        case .transitionOverlap:
            return "Remove or adjust the overlapping transition"
        }
    }

    /// Test if two errors are equal (needed for Equatable conformance with LocalizedError)
    static func == (lhs: TransitionError, rhs: TransitionError) -> Bool {
        switch (lhs, rhs) {
        case (.durationExceedsOverlap(let a1, let a2), .durationExceedsOverlap(let b1, let b2)):
            return a1 == b1 && a2 == b2
        case (.invalidParameters(let a), .invalidParameters(let b)):
            return a == b
        case (.clipsNotFound(let a1, let a2), .clipsNotFound(let b1, let b2)):
            return a1 == b1 && a2 == b2
        case (.insufficientOverlap(let a1, let a2), .insufficientOverlap(let b1, let b2)):
            return a1 == b1 && a2 == b2
        case (.parameterOutOfRange(let a1, let a2), .parameterOutOfRange(let b1, let b2)):
            return a1 == b1 && a2 == b2
        case (.transitionOverlap(let a), .transitionOverlap(let b)):
            return a == b
        default:
            return false
        }
    }
}
