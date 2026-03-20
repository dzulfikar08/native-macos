import AppKit

/// Codable wrapper for NSColor to enable persistence
struct TimelineColor: Codable, Sendable, Equatable {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    /// Initialize from NSColor, extracting RGB components
    init(from color: NSColor) {
        let rgbColor = color.usingColorSpace(.deviceRGB) ?? color
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        rgbColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        red = r
        green = g
        blue = b
        alpha = a
    }

    /// Initialize with direct RGB values
    init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Convert back to NSColor
    var nsColor: NSColor {
        return NSColor(deviceRed: red, green: green, blue: blue, alpha: alpha)
    }

    /// Description for UI tooltips
    var rawValue: String {
        switch self {
        case _ where self == TimelineColor.blue:
            return "Blue"
        case _ where self == TimelineColor.green:
            return "Green"
        case _ where self == TimelineColor.orange:
            return "Orange"
        case _ where self == TimelineColor.purple:
            return "Purple"
        case _ where self == TimelineColor.pink:
            return "Pink"
        default:
            return "Custom"
        }
    }

    /// Predefined colors for UI elements
    static let blue = TimelineColor(from: NSColor(red: 0, green: 0.478, blue: 1, alpha: 1))
    static let green = TimelineColor(from: NSColor(red: 0.204, green: 0.78, blue: 0.349, alpha: 1))
    static let orange = TimelineColor(from: NSColor(red: 1, green: 0.584, blue: 0, alpha: 1))
    static let purple = TimelineColor(from: NSColor(red: 0.686, green: 0.322, blue: 0.871, alpha: 1))
    static let pink = TimelineColor(from: NSColor(red: 1, green: 0.176, blue: 0.333, alpha: 1))

    /// Random color from predefined palette
    static func random() -> TimelineColor {
        let colors: [TimelineColor] = [.blue, .green, .orange, .purple, .pink]
        return colors.randomElement() ?? .blue
    }
}
