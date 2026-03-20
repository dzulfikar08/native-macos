import AVFoundation
import CoreImage
import CoreMedia
import CoreVideo

/// Renders cross-dissolve transitions
struct CrossfadeRenderer: TransitionRenderer {

    /// Shared Core Image context for rendering
    /// CIContext creation is expensive, so we reuse a single instance
    private static let ciContext: CIContext = {
        let options: [CIContextOption: Any] = [
            .useSoftwareRenderer: false,
            .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        ]
        return CIContext(options: options)
    }()

    func render(
        sourceBuffer: CVPixelBuffer,
        targetBuffer: CVPixelBuffer,
        progress: Double,
        transition: TransitionClip
    ) throws -> CVPixelBuffer {

        guard progress >= 0.0 && progress <= 1.0 else {
            throw TransitionError.parameterOutOfRange("progress", validRange: 0.0...1.0)
        }

        // Reuse shared Core Image context for performance

        // Create images from pixel buffers
        let sourceImage = CIImage(cvPixelBuffer: sourceBuffer)
        let targetImage = CIImage(cvPixelBuffer: targetBuffer)

        // Create dissolve filter for crossfade transition
        guard let dissolveFilter = CIFilter(name: "CIDissolveTransition") else {
            throw TransitionError.invalidParameters(reason: "Failed to create CIDissolveTransition filter")
        }

        dissolveFilter.setValue(sourceImage, forKey: kCIInputImageKey)
        dissolveFilter.setValue(targetImage, forKey: kCIInputTargetImageKey)
        dissolveFilter.setValue(progress, forKey: kCIInputTimeKey)

        guard let outputImage = dissolveFilter.outputImage else {
            throw TransitionError.invalidParameters(reason: "Failed to apply dissolve filter")
        }

        // Render to new pixel buffer
        let outputBuffer = try createPixelBuffer(from: sourceBuffer)

        Self.ciContext.render(outputImage, to: outputBuffer)

        return outputBuffer
    }

    /// Creates a new pixel buffer matching the source format
    private func createPixelBuffer(from source: CVPixelBuffer) throws -> CVPixelBuffer {
        let width = CVPixelBufferGetWidth(source)
        let height = CVPixelBufferGetHeight(source)
        let pixelFormat = CVPixelBufferGetPixelFormatType(source)

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            pixelFormat,
            nil,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let output = pixelBuffer else {
            throw TransitionError.invalidParameters(reason: "Failed to create pixel buffer")
        }

        return output
    }
}
