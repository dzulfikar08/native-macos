import Foundation

/// The type of video transition effect
enum TransitionType: Codable, Sendable {
    /// Crossfade dissolve between clips
    case crossfade

    /// Fade to a solid color (black, white, or custom)
    case fadeToColor

    /// Directional wipe transition
    case wipe

    /// Shape-based iris reveal
    case iris

    /// Blinds effect
    case blinds

    /// Custom transition with identifier
    case custom(String)

    /// Human-readable name for the transition type
    var displayName: String {
        switch self {
        case .crossfade:
            return "Crossfade"
        case .fadeToColor:
            return "Fade to Color"
        case .wipe:
            return "Wipe"
        case .iris:
            return "Iris"
        case .blinds:
            return "Blinds"
        case .custom(let name):
            return name
        }
    }

    /// Default duration for this transition type (in seconds)
    var defaultDuration: Double {
        switch self {
        case .crossfade:
            return 1.0
        case .fadeToColor:
            return 1.5
        case .wipe:
            return 1.0
        case .iris:
            return 1.5
        case .blinds:
            return 1.0
        case .custom:
            return 1.0
        }
    }

    /// Category for UI organization
    var category: TransitionCategory {
        switch self {
        case .crossfade, .fadeToColor:
            return .basic
        case .wipe, .blinds:
            return .directional
        case .iris:
            return .shape
        case .custom:
            return .custom
        }
    }

    /// All built-in transition types (excludes custom)
    static var builtInCases: [TransitionType] {
        return [.crossfade, .fadeToColor, .wipe, .iris, .blinds]
    }
}

/// Explicit Equatable conformance for TransitionType
extension TransitionType: Equatable {
    static func == (lhs: TransitionType, rhs: TransitionType) -> Bool {
        switch (lhs, rhs) {
        case (.crossfade, .crossfade),
             (.fadeToColor, .fadeToColor),
             (.wipe, .wipe),
             (.iris, .iris),
             (.blinds, .blinds):
            return true
        case (.custom(let n1), .custom(let n2)):
            return n1 == n2
        default:
            return false
        }
    }
}

/// Category for organizing transitions in UI
enum TransitionCategory: String, Codable, Sendable {
    case basic
    case directional
    case shape
    case custom
}
