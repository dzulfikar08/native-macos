import Foundation
import AppKit

/// Item displayed in transitions palette outline view
struct TransitionPaletteItem {
    let preset: TransitionPreset
    let category: TransitionCategory

    /// Display name for outline view
    var displayName: String {
        "\(preset.name) (\(formatDuration(preset.duration)))"
    }

    /// SF Symbol icon for preset type
    var iconName: String {
        switch preset.transitionType {
        case .crossfade: return "circle.circle"
        case .fadeToColor: return "circle.lefthalf.filled"
        case .wipe: return "arrow.right.circle.fill"
        case .iris: return "circle.circle"
        case .blinds: return "line.3.horizontal"
        case .custom: return "star.fill"
        }
    }

    /// Accent color based on category
    var categoryColor: NSColor {
        switch category {
        case .basic: return .systemBlue
        case .directional: return .systemGreen
        case .shape: return .systemOrange
        case .custom: return .systemPurple
        }
    }
}
