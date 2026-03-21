import Foundation
import CoreMedia

/// Built-in transition presets
enum BuiltInPresets {
    /// Generates deterministic UUIDs for built-in presets
    private static func presetUUID(name: String) -> UUID {
        let namespace = UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8")!
        let hash = name.djb2Hash

        let uuidString = String(format: "%@-%04x-4000-8000-%012x",
                                String(namespace.uuidString.prefix(8)),
                                hash % 10000,
                                hash % 1000000000000)
        return UUID(uuidString: uuidString)!
    }

    static let presets: [TransitionPreset] = [
        // Quick Dissolve - Fast crossfade
        TransitionPreset(
            id: presetUUID(name: "quick-dissolve"),
            name: "Quick Dissolve",
            isBuiltIn: true,
            transitionType: .crossfade,
            parameters: .crossfade,
            duration: CMTime(seconds: 0.5, preferredTimescale: 600)
        ),

        // Slow Fade - Dramatic fade to black
        TransitionPreset(
            id: presetUUID(name: "slow-fade"),
            name: "Slow Fade",
            isBuiltIn: true,
            transitionType: .fadeToColor,
            parameters: .fadeToColor(color: .black, holdDuration: 0.5),
            duration: CMTime(seconds: 2.0, preferredTimescale: 600)
        ),

        // Wipe Left - Classic horizontal wipe
        TransitionPreset(
            id: presetUUID(name: "wipe-left"),
            name: "Wipe Left",
            isBuiltIn: true,
            transitionType: .wipe,
            parameters: .wipe(direction: .left, softness: 0.2, borderWidth: 0),
            duration: CMTime(seconds: 1.0, preferredTimescale: 600)
        ),

        // Circle Reveal - Classic iris
        TransitionPreset(
            id: presetUUID(name: "circle-reveal"),
            name: "Circle Reveal",
            isBuiltIn: true,
            transitionType: .iris,
            parameters: .iris(shape: .circle, position: CGPoint(x: 0.5, y: 0.5), softness: 0.3),
            duration: CMTime(seconds: 1.5, preferredTimescale: 600)
        ),

        // Vertical Blinds - Classic blinds
        TransitionPreset(
            id: presetUUID(name: "vertical-blinds"),
            name: "Vertical Blinds",
            isBuiltIn: true,
            transitionType: .blinds,
            parameters: .blinds(orientation: .vertical, slatCount: 10),
            duration: CMTime(seconds: 1.0, preferredTimescale: 600)
        )
    ]
}

/// String hashing for deterministic UUID generation
extension String {
    var djb2Hash: UInt64 {
        var hash: UInt64 = 5381
        for char in self.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(char)
        }
        return hash
    }
}
