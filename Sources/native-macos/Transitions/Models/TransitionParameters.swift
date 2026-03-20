import Foundation
import CoreGraphics

/// Direction for wipe transitions
enum WipeDirection: String, Codable, Sendable, CaseIterable {
    case left
    case right
    case up
    case down
    case diagonalLeft
    case diagonalRight
}

/// Shape for iris transitions
enum IrisShape: String, Codable, Sendable, CaseIterable {
    case circle
    case square
    case star
    case triangle
}

/// Orientation for blinds transitions
enum BlindsOrientation: String, Codable, Sendable, CaseIterable {
    case horizontal
    case vertical
}

/// RGBA color for transitions
struct TransitionColor: Equatable, Codable, Sendable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    /// Validates color values are in [0, 1]
    var isValid: Bool {
        return (0...1).contains(red) &&
               (0...1).contains(green) &&
               (0...1).contains(blue) &&
               (0...1).contains(alpha)
    }

    /// Predefined colors
    static let black = TransitionColor(red: 0, green: 0, blue: 0, alpha: 1)
    static let white = TransitionColor(red: 1, green: 1, blue: 1, alpha: 1)

    init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

/// Type-safe parameters for transition effects
enum TransitionParameters: Equatable, Codable, Sendable {
    /// No additional parameters (crossfade default)
    case crossfade

    /// Fade to solid color with duration
    case fadeToColor(color: TransitionColor, holdDuration: Double)

    /// Directional wipe with softness and border
    case wipe(direction: WipeDirection, softness: Double, borderWidth: Double)

    /// Shape-based iris reveal with position and softness
    case iris(shape: IrisShape, position: CGPoint, softness: Double)

    /// Blinds effect with orientation and slat count
    case blinds(orientation: BlindsOrientation, slatCount: Int)

    /// Custom parameters with string keys
    case custom(parameters: [String: Double])

    /// Validates parameters are within acceptable ranges
    var isValid: Bool {
        switch self {
        case .crossfade:
            return true

        case .fadeToColor(let color, let holdDuration):
            return color.isValid && holdDuration >= 0 && holdDuration <= 5.0

        case .wipe(_, let softness, let borderWidth):
            return softness >= 0 && softness <= 1.0 && borderWidth >= 0 && borderWidth <= 20.0

        case .iris(_, let position, let softness):
            return (position.x >= 0 && position.x <= 1.0) &&
                   (position.y >= 0 && position.y <= 1.0) &&
                   softness >= 0 && softness <= 1.0

        case .blinds(_, let slatCount):
            return slatCount >= 2 && slatCount <= 50

        case .custom(let parameters):
            return parameters.allSatisfy { $0.value.isFinite }
        }
    }

    /// Default parameters for a given transition type
    static func `default`(for type: TransitionType) -> TransitionParameters {
        switch type {
        case .crossfade:
            return .crossfade

        case .fadeToColor:
            return .fadeToColor(color: .black, holdDuration: 0.5)

        case .wipe:
            return .wipe(direction: .left, softness: 0.2, borderWidth: 0)

        case .iris:
            return .iris(shape: .circle, position: CGPoint(x: 0.5, y: 0.5), softness: 0.3)

        case .blinds:
            return .blinds(orientation: .vertical, slatCount: 10)

        case .custom:
            return .custom(parameters: [:])
        }
    }

    /// Explicit Equatable conformance for CGPoint comparison
    static func == (lhs: TransitionParameters, rhs: TransitionParameters) -> Bool {
        switch (lhs, rhs) {
        case (.crossfade, .crossfade):
            return true

        case (.fadeToColor(let c1, let h1), .fadeToColor(let c2, let h2)):
            return c1 == c2 && h1 == h2

        case (.wipe(let d1, let s1, let b1), .wipe(let d2, let s2, let b2)):
            return d1 == d2 && s1 == s2 && b1 == b2

        case (.iris(let s1, let p1, let so1), .iris(let s2, let p2, let so2)):
            return s1 == s2 && p1.x == p2.x && p1.y == p2.y && so1 == so2

        case (.blinds(let o1, let c1), .blinds(let o2, let c2)):
            return o1 == o2 && c1 == c2

        case (.custom(let p1), .custom(let p2)):
            return p1 == p2

        default:
            return false
        }
    }
}
