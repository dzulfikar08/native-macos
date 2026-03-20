import AVFoundation
import CoreImage
import CoreMedia
import CoreVideo

/// Renders circular iris/wipe transitions
struct IrisRenderer: TransitionRenderer {

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

        // Calculate iris radius
        // At progress 0, radius is 0 (fully closed)
        // At progress 1, radius covers the entire frame
        let maxRadius = max(CGFloat(width), CGFloat(height))
        let currentRadius = CGFloat(progress) * maxRadius

        // Create radial gradient mask
        // Inside circle (radius 0 to currentRadius): 1.0 (target)
        // Outside circle (currentRadius to maxRadius): 0.0 (source)
        guard let gradientFilter = CIFilter(name: "CIRadialGradient") else {
            throw TransitionError.invalidParameters(reason: "Failed to create CIRadialGradient filter")
        }

        let centerX = CGFloat(width) / 2.0
        let centerY = CGFloat(height) / 2.0

        gradientFilter.setValue(CIVector(x: centerX, y: centerY), forKey: "inputCenter")
        gradientFilter.setValue(currentRadius, forKey: "inputRadius0")
        gradientFilter.setValue(CIColor(red: 1, green: 1, blue: 1), forKey: "inputColor0")
        gradientFilter.setValue(maxRadius, forKey: "inputRadius1")
        gradientFilter.setValue(CIColor(red: 0, green: 0, blue: 0), forKey: "inputColor1")

        guard let maskImage = gradientFilter.outputImage else {
            throw TransitionError.invalidParameters(reason: "Failed to create gradient mask")
        }

        // Crop mask to frame bounds
        let croppedMask = maskImage.cropped(to: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))

        // Blend images using mask
        // Mask values: 1.0 = show target (inside circle), 0.0 = show source (outside circle)
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
