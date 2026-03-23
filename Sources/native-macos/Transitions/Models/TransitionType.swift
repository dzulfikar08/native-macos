import Foundation

/// The type of video transition effect
enum TransitionType: Codable, Sendable, Equatable {
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

    /// Raw string value for the transition type
    var rawValue: String {
        switch self {
        case .crossfade:
            return "crossfade"
        case .fadeToColor:
            return "fadeToColor"
        case .wipe:
            return "wipe"
        case .iris:
            return "iris"
        case .blinds:
            return "blinds"
        case .custom(let name):
            return "custom:\(name)"
        }
    }

    /// Initialize from raw value string
    /// - Parameter rawValue: The raw string value
    init?(rawValue: String) {
        if rawValue.hasPrefix("custom:") {
            let name = String(rawValue.dropFirst(7)) // Remove "custom:" prefix
            self = .custom(name)
        } else {
            switch rawValue {
            case "crossfade":
                self = .crossfade
            case "fadeToColor":
                self = .fadeToColor
            case "wipe":
                self = .wipe
            case "iris":
                self = .iris
            case "blinds":
                self = .blinds
            default:
                return nil
            }
        }
    }

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

    /// All standard (non-custom) transition types
    static var allStandardTypes: [TransitionType] {
        [.crossfade, .fadeToColor, .wipe, .iris, .blinds]
    }

    /// All standard transition types (alias for allStandardTypes)
    static var allCases: [TransitionType] {
        return allStandardTypes
    }
}

// MARK: - Equatable
extension TransitionType {
    static func == (lhs: TransitionType, rhs: TransitionType) -> Bool {
        switch (lhs, rhs) {
        case (.crossfade, .crossfade),
             (.fadeToColor, .fadeToColor),
             (.wipe, .wipe),
             (.iris, .iris),
             (.blinds, .blinds):
            return true
        case (.custom(let lhsName), .custom(let rhsName)):
            return lhsName == rhsName
        default:
            return false
        }
    }
}

// MARK: - Codable
extension TransitionType {
    private enum CodingKeys: String, CodingKey {
        case type
        case customName
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .crossfade, .fadeToColor, .wipe, .iris, .blinds:
            try container.encode(self.rawValue, forKey: .type)
        case .custom(let name):
            try container.encode("custom", forKey: .type)
            try container.encode(name, forKey: .customName)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeString = try container.decode(String.self, forKey: .type)

        if typeString == "custom" {
            let name = try container.decode(String.self, forKey: .customName)
            self = .custom(name)
        } else {
            switch typeString {
            case "crossfade":
                self = .crossfade
            case "fadeToColor":
                self = .fadeToColor
            case "wipe":
                self = .wipe
            case "iris":
                self = .iris
            case "blinds":
                self = .blinds
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .type,
                    in: container,
                    debugDescription: "Invalid transition type: \(typeString)"
                )
            }
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
