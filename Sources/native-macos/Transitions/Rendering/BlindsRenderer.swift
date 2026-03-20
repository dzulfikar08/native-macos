import AVFoundation
import CoreImage
import CoreMedia
import CoreVideo

/// Renders horizontal blinds/slats transitions
struct BlindsRenderer: TransitionRenderer {

    /// Shared Core Image context for rendering
    /// CIContext creation is expensive, so we reuse a single instance
    private static let ciContext: CIContext = {
        let options: [CIContextOption: Any] = [
            .useSoftwareRenderer: false,
            .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        ]
        return CIContext(options: options)
    }()

    /// Number of horizontal slats in the blinds effect
    private let numberOfSlats = 10

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

        // Calculate slat height
        let slatHeight = CGFloat(height) / CGFloat(numberOfSlats)

        // Process each slat
        var compositedImage = sourceImage

        for slatIndex in 0..<numberOfSlats {
            // Calculate independent progress for this slat
            // Each slat is offset by its position to create cascading effect
            let slatOffset = Double(slatIndex) / Double(numberOfSlats)
            let slatProgress = (progress + slatOffset).truncatingRemainder(dividingBy: 1.0)

            // Create gradient mask for this slat
            let slatY = CGFloat(slatIndex) * slatHeight

            guard let gradientFilter = CIFilter(name: "CILinearGradient") else {
                throw TransitionError.invalidParameters(reason: "Failed to create CILinearGradient filter")
            }

            // Gradient from left to right across the slat
            gradientFilter.setValue(CIVector(x: 0, y: slatY), forKey: "inputPoint0")
            gradientFilter.setValue(CIColor(red: 0, green: 0, blue: 0), forKey: "inputColor0")
            gradientFilter.setValue(
                CIVector(x: CGFloat(slatProgress) * CGFloat(width), y: slatY),
                forKey: "inputPoint1"
            )
            gradientFilter.setValue(CIColor(red: 1, green: 1, blue: 1), forKey: "inputColor1")

            guard let maskImage = gradientFilter.outputImage else {
                throw TransitionError.invalidParameters(reason: "Failed to create gradient mask")
            }

            // Crop mask to this slat's region
            let slatRect = CGRect(
                x: 0,
                y: slatY,
                width: CGFloat(width),
                height: slatHeight
            )
            let croppedMask = maskImage.cropped(to: slatRect)

            // Extend mask to full frame size for compositing
            let fullFrameMask = croppedMask.composited(
                over: CIImage(color: CIColor(red: 0, green: 0, blue: 0))
                    .cropped(to: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
            )

            // Blend this slat
            guard let blendFilter = CIFilter(name: "CIBlendWithMask") else {
                throw TransitionError.invalidParameters(reason: "Failed to create CIBlendWithMask filter")
            }

            blendFilter.setValue(compositedImage, forKey: kCIInputBackgroundImageKey)
            blendFilter.setValue(targetImage, forKey: kCIInputImageKey)
            blendFilter.setValue(fullFrameMask, forKey: kCIInputMaskImageKey)

            guard let blendedImage = blendFilter.outputImage else {
                throw TransitionError.invalidParameters(reason: "Failed to blend slat")
            }

            compositedImage = blendedImage
        }

        // Render to new pixel buffer
        return try renderImage(compositedImage, from: sourceBuffer)
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
