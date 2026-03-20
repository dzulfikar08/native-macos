import AVFoundation
import CoreMedia
import CoreVideo

/// Provides renderers for different transition types
@MainActor
final class TransitionRenderContext {

    /// Returns the appropriate renderer for a transition
    /// - Parameter transition: The transition to render
    /// - Returns: Renderer for the transition type
    func renderer(for transition: TransitionClip) -> TransitionRenderer {
        switch transition.type {
        case .crossfade:
            return CrossfadeRenderer()
        case .fadeToColor:
            return FadeToColorRenderer()
        case .wipe:
            return WipeRenderer()
        case .iris:
            return IrisRenderer()
        case .blinds:
            return BlindsRenderer()
        case .custom:
            return CrossfadeRenderer() // Default to crossfade for custom
        }
    }
}

/// Protocol for transition renderers
internal protocol TransitionRenderer {
    /// Applies the transition effect to a pixel buffer
    /// - Parameters:
    ///   - sourceBuffer: The source pixel buffer (leading clip frame)
    ///   - targetBuffer: The target pixel buffer (trailing clip frame)
    ///   - progress: Progress through transition (0.0 to 1.0)
    ///   - transition: The transition being rendered
    /// - Returns: Processed pixel buffer with transition applied
    func render(
        sourceBuffer: CVPixelBuffer,
        targetBuffer: CVPixelBuffer,
        progress: Double,
        transition: TransitionClip
    ) throws -> CVPixelBuffer
}
