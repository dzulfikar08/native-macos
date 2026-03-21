import Foundation
import AppKit
import CoreImage
import CoreMedia
import CoreVideo
import AVFoundation

/// Adapter for rendering transitions with CIImage interface
/// Bridges the gap between CIImage-based preview rendering and CVPixelBuffer-based renderers
@MainActor
final class TransitionPreviewRenderer {
    private let renderContext: TransitionRenderContext

    /// Shared Core Image context for rendering
    private static let ciContext: CIContext = {
        let options: [CIContextOption: Any] = [
            .useSoftwareRenderer: false,
            .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        ]
        return CIContext(options: options)
    }()

    init(renderContext: TransitionRenderContext = TransitionRenderContext()) {
        self.renderContext = renderContext
    }

    /// Applies transition between two CIImages
    /// - Parameters:
    ///   - leadingFrame: The leading clip frame (source)
    ///   - trailingFrame: The trailing clip frame (target)
    ///   - transition: The transition to apply
    ///   - progress: Progress through transition (0.0 to 1.0)
    /// - Returns: Rendered CIImage with transition applied, or nil if unsupported
    func applyTransition(
        from leadingFrame: CIImage,
        to trailingFrame: CIImage,
        transition: TransitionClip,
        progress: Double
    ) -> CIImage? {
        // Convert CIImages to CVPixelBuffers
        guard let leadingBuffer = try? createPixelBuffer(from: leadingFrame),
              let trailingBuffer = try? createPixelBuffer(from: trailingFrame) else {
            return nil
        }

        // Get the appropriate renderer for this transition type
        let renderer = renderContext.renderer(for: transition)

        // Apply transition
        do {
            let outputBuffer = try renderer.render(
                sourceBuffer: leadingBuffer,
                targetBuffer: trailingBuffer,
                progress: progress,
                transition: transition
            )

            // Convert result back to CIImage
            return CIImage(cvPixelBuffer: outputBuffer)
        } catch {
            print("Transition rendering failed: \(error)")
            return nil
        }
    }

    /// Creates a CVPixelBuffer from a CIImage
    private func createPixelBuffer(from image: CIImage) throws -> CVPixelBuffer {
        // Get image extent
        let extent = image.extent
        let width = Int(extent.width)
        let height = Int(extent.height)

        // Create pixel buffer
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            nil,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let output = pixelBuffer else {
            throw TransitionError.invalidParameters(reason: "Failed to create pixel buffer from CIImage")
        }

        // Render CIImage to pixel buffer
        Self.ciContext.render(image, to: output)

        return output
    }

    /// Invalidates any cached resources
    func invalidateCache() {
        // No-op for now - could be used to clear shader caches in the future
    }
}
