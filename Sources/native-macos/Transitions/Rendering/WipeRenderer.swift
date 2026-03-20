import AVFoundation
import CoreImage
import CoreMedia
import CoreVideo

/// Renders horizontal wipe transitions
struct WipeRenderer: TransitionRenderer {

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

        let width = CVPixelBufferGetWidth(sourceBuffer)
        let height = CVPixelBufferGetHeight(sourceBuffer)

        // Create images from pixel buffers
        let sourceImage = CIImage(cvPixelBuffer: sourceBuffer)
        let targetImage = CIImage(cvPixelBuffer: targetBuffer)

        // Calculate wipe position (x-coordinate where transition occurs)
        let wipeX = CGFloat(progress) * CGFloat(width)

        // Create horizontal gradient mask
        // Gradient goes from 0 to 1 at the wipe position
        guard let gradientFilter = CIFilter(name: "CILinearGradient") else {
            throw TransitionError.invalidParameters(reason: "Failed to create CILinearGradient filter")
        }

        gradientFilter.setValue(CIVector(x: 0, y: CGFloat(height) / 2.0), forKey: "inputPoint0")
        gradientFilter.setValue(CIColor(red: 0, green: 0, blue: 0), forKey: "inputColor0")
        gradientFilter.setValue(CIVector(x: wipeX, y: CGFloat(height) / 2.0), forKey: "inputPoint1")
        gradientFilter.setValue(CIColor(red: 1, green: 1, blue: 1), forKey: "inputColor1")

        guard let maskImage = gradientFilter.outputImage else {
            throw TransitionError.invalidParameters(reason: "Failed to create gradient mask")
        }

        // Crop mask to frame bounds
        let croppedMask = maskImage.cropped(to: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))

        // Blend images using mask
        // Mask values: 0 = show source, 1 = show target
        guard let blendFilter = CIFilter(name: "CIBlendWithMask") else {
            throw TransitionError.invalidParameters(reason: "Failed to create CIBlendWithMask filter")
        }

        blendFilter.setValue(sourceImage, forKey: kCIInputBackgroundImageKey)
        blendFilter.setValue(targetImage, forKey: kCIInputImageKey)
        blendFilter.setValue(croppedMask, forKey: kCIInputMaskImageKey)

        guard let outputImage = blendFilter.outputImage else {
            throw TransitionError.invalidParameters(reason: "Failed to blend images")
        }

        // Render to new pixel buffer
        return try renderImage(outputImage, from: sourceBuffer)
    }

    private func renderImage(_ image: CIImage, from source: CVPixelBuffer) throws -> CVPixelBuffer {
        let outputBuffer = try createPixelBuffer(from: source)
        Self.ciContext.render(image, to: outputBuffer)
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
