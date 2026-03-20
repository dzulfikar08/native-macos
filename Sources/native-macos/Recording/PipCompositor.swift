import CoreImage
import CoreVideo
import Foundation

/// Composes multiple camera feeds into picture-in-picture layouts
struct PipCompositor: Sendable {
    private let ciContext: CIContext

    init() {
        // Use GPU-accelerated context when available
        self.ciContext = CIContext(options: [.useSoftwareRenderer: false])
    }

    /// Calculate layout rect for a camera in given mode
    func calculateRect(for index: Int, mode: PipMode, in size: CGSize) -> CGRect {
        switch mode {
        case .single:
            return CGRect(origin: .zero, size: size)

        case .dual(let main, let overlay):
            if index == main {
                // Main: 75% width, full height
                return CGRect(
                    x: 0,
                    y: 0,
                    width: size.width * 0.75,
                    height: size.height
                )
            } else if index == overlay {
                // Overlay: 25% width, 25% height, top-right
                return CGRect(
                    x: size.width * 0.75,
                    y: 0,
                    width: size.width * 0.25,
                    height: size.height * 0.25
                )
            } else {
                return .zero
            }

        case .triple(let main, let p2, let p3):
            if index == main {
                // Main: 70% width, full height
                return CGRect(
                    x: 0,
                    y: 0,
                    width: size.width * 0.70,
                    height: size.height
                )
            } else if index == p2 {
                // Camera 2: 30% width, 50% height, top-left
                return CGRect(
                    x: size.width * 0.70,
                    y: 0,
                    width: size.width * 0.30,
                    height: size.height * 0.50
                )
            } else if index == p3 {
                // Camera 3: 30% width, 50% height, top-right
                return CGRect(
                    x: size.width * 0.70,
                    y: size.height * 0.50,
                    width: size.width * 0.30,
                    height: size.height * 0.50
                )
            } else {
                return .zero
            }

        case .quad:
            // 2x2 grid
            let col = index % 2
            let row = index / 2

            return CGRect(
                x: size.width * CGFloat(col) * 0.5,
                y: size.height * CGFloat(row) * 0.5,
                width: size.width * 0.5,
                height: size.height * 0.5
            )
        }
    }

    /// Compose frame from multiple camera buffers
    /// - Parameters:
    ///   - buffers: Dictionary mapping camera index to pixel buffer
    ///   - outputBuffer: Destination buffer
    ///   - mode: PIP compositing mode
    /// - Throws: CIError if composition fails
    func composeFrame(
        buffers: [Int: CVPixelBuffer],
        into outputBuffer: CVPixelBuffer,
        mode: PipMode
    ) throws {
        var currentImage = CIImage()

        let outputWidth = CGFloat(CVPixelBufferGetWidth(outputBuffer))
        let outputHeight = CGFloat(CVPixelBufferGetHeight(outputBuffer))
        let outputSize = CGSize(width: outputWidth, height: outputHeight)

        // Sort buffers by index for consistent layering
        for (index, buffer) in buffers.sorted(by: { $0.key < $1.key }) {
            let rect = calculateRect(for: index, mode: mode, in: outputSize)

            let image = CIImage(cvPixelBuffer: buffer)

            // Calculate scale to fit rect
            let bufferWidth = CGFloat(CVPixelBufferGetWidth(buffer))
            let bufferHeight = CGFloat(CVPixelBufferGetHeight(buffer))
            let scaleX = rect.width / bufferWidth
            let scaleY = rect.height / bufferHeight

            // Transform: scale → crop → translate
            let scaled = image
                .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
                .cropped(to: CGRect(origin: .zero, size: rect.size))
                .transformed(by: CGAffineTransform(translationX: rect.origin.x, y: rect.origin.y))

            if index == buffers.keys.first {
                currentImage = scaled
            } else {
                currentImage = scaled.composited(over: currentImage)
            }
        }

        // Render to output buffer
        try ciContext.render(currentImage, to: outputBuffer)
    }
}

enum CompositorError: LocalizedError {
    case compositionFailed(String)

    var errorDescription: String? {
        switch self {
        case .compositionFailed(let reason):
            return "Frame composition failed: \(reason)"
        }
    }
}
