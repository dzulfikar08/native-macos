import AVFoundation
import CoreImage
import CoreMedia
import CoreVideo

/// Renders fade to/from color transitions
struct FadeToColorRenderer: TransitionRenderer {

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

        guard case .fadeToColor(let color, _) = transition.parameters else {
            throw TransitionError.invalidParameters(reason: "Expected FadeToColorParameters")
        }

        let width = CVPixelBufferGetWidth(sourceBuffer)
        let height = CVPixelBufferGetHeight(sourceBuffer)

        // First half: fade to color
        // Second half: fade from color to target
        let adjustedProgress: Double
        let baseImage: CIImage
        let overlayImage: CIImage
        let opacity: Float

        if progress < 0.5 {
            // Fading to color (0.0 to 0.5)
            adjustedProgress = progress * 2.0 // 0.0 to 1.0
            baseImage = CIImage(cvPixelBuffer: sourceBuffer)
            overlayImage = CIImage(color: convertToCIColor(color))
                .cropped(to: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
            opacity = Float(adjustedProgress)
        } else {
            // Fading from color to target (0.5 to 1.0)
            adjustedProgress = (progress - 0.5) * 2.0 // 0.0 to 1.0
            baseImage = CIImage(cvPixelBuffer: targetBuffer)
            overlayImage = CIImage(color: convertToCIColor(color))
                .cropped(to: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
            opacity = Float(1.0 - adjustedProgress)
        }

        // Create color image with opacity
        guard let colorFilter = CIFilter(name: "CIColorMatrix") else {
            throw TransitionError.invalidParameters(reason: "Failed to create CIColorMatrix filter")
        }

        colorFilter.setValue(overlayImage, forKey: kCIInputImageKey)
        colorFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputRVector")
        colorFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputGVector")
        colorFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputBVector")
        colorFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: CGFloat(opacity)), forKey: "inputAVector")
        colorFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputBiasVector")

        guard let coloredImage = colorFilter.outputImage else {
            throw TransitionError.invalidParameters(reason: "Failed to apply color matrix filter")
        }

        // Blend color with base image
        guard let blendFilter = CIFilter(name: "CISourceOverCompositing") else {
            throw TransitionError.invalidParameters(reason: "Failed to create CISourceOverCompositing filter")
        }

        blendFilter.setValue(coloredImage, forKey: kCIInputImageKey)
        blendFilter.setValue(baseImage, forKey: kCIInputBackgroundImageKey)

        guard let outputImage = blendFilter.outputImage else {
            throw TransitionError.invalidParameters(reason: "Failed to blend images")
        }

        // Render to new pixel buffer
        let outputBuffer = try createPixelBuffer(from: sourceBuffer)

        Self.ciContext.render(outputImage, to: outputBuffer)

        return outputBuffer
    }

    /// Converts TransitionColor to CIColor
    private func convertToCIColor(_ color: TransitionColor) -> CIColor {
        return CIColor(
            red: CGFloat(color.red),
            green: CGFloat(color.green),
            blue: CGFloat(color.blue),
            alpha: CGFloat(color.alpha)
        )
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
