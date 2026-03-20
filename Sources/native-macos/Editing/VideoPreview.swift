import AppKit
import MetalKit
import CoreImage
import AVFoundation

/// MetalKit view for displaying video frames
@MainActor
final class VideoPreview: MTKView {
    private var metalRenderer: MetalRenderer?
    private var videoEffectProcessor: VideoEffectProcessor?
    private var textureCache: CVMetalTextureCache?
    private var ciContext: CIContext?

    // Editor state reference for accessing effects
    weak var editorState: EditorState?

    override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device ?? MTLCreateSystemDefaultDevice())
        setupView()
        setupRenderer()
        setupEffects()
        setupTextureCache()
        setupCIContext()
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        setupRenderer()
        setupEffects()
        setupTextureCache()
        setupCIContext()
    }

    private func setupView() {
        self.enableSetNeedsDisplay = false  // Enable realtime rendering
        self.isPaused = false
        self.preferredFramesPerSecond = 60
        self.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
    }

    private func setupRenderer() {
        guard let device = self.device else { return }
        metalRenderer = MetalRenderer(device: device)

        do {
            try metalRenderer?.setupPipeline(view: self)
        } catch {
            print("⚠️ Failed to setup Metal pipeline: \(error)")
        }
    }

    private func setupEffects() {
        videoEffectProcessor = VideoEffectProcessor()
    }

    private func setupTextureCache() {
        guard let device = self.device else { return }
        let result = CVMetalTextureCacheCreate(
            kCFAllocatorDefault,
            nil,
            device,
            nil,
            &textureCache
        )
        guard result == kCVReturnSuccess else {
            print("⚠️ Failed to create Metal texture cache")
            return
        }
    }

    private func setupCIContext() {
        ciContext = CIContext(options: [
            .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            .useSoftwareRenderer: false
        ])
    }

    /// Render a pixel buffer with effects applied
    func renderFrame(_ pixelBuffer: CVPixelBuffer, at time: CMTime) {
        // Get enabled effects that apply to current time
        let applicableEffects = getEnabledEffects(for: time)

        // Create CIImage from pixel buffer
        var image = CIImage(cvPixelBuffer: pixelBuffer)

        // Apply effects if any
        if !applicableEffects.isEmpty {
            if let processedImage = videoEffectProcessor?.applyEffects(to: image, effects: applicableEffects) {
                image = processedImage
            }
        }

        // Convert to Metal texture and render
        if let texture = createTexture(from: image, pixelBuffer: pixelBuffer) {
            metalRenderer?.render(texture: texture, in: self)
        }
    }

    /// Get effects that are enabled and applicable to the current time
    private func getEnabledEffects(for time: CMTime) -> [VideoEffect] {
        guard let editorState = editorState else { return [] }

        return editorState.effectStack.videoEffects.filter { effect in
            // Filter by enabled state
            guard effect.isEnabled else { return false }

            // Filter by time range if specified
            if let timeRange = effect.timeRange {
                let timeInSeconds = CMTimeGetSeconds(time)
                let lower = CMTimeGetSeconds(timeRange.lowerBound)
                let upper = CMTimeGetSeconds(timeRange.upperBound)
                return timeInSeconds >= lower && timeInSeconds <= upper
            }

            return true
        }
    }

    /// Create Metal texture from CIImage
    private func createTexture(from image: CIImage, pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        guard let device = self.device,
              let ciContext = ciContext,
              let textureCache = textureCache else { return nil }

        // Render CIImage to pixel buffer
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        guard let outputPixelBuffer = createOutputPixelBuffer(width: width, height: height) else {
            return nil
        }

        ciContext.render(image, to: outputPixelBuffer)

        // Convert to Metal texture
        var metalTexture: CVMetalTexture?
        let result = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            outputPixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &metalTexture
        )

        guard result == kCVReturnSuccess,
              let texture = metalTexture else {
            return nil
        }

        return CVMetalTextureGetTexture(texture)
    }

    /// Create output pixel buffer for rendering
    private func createOutputPixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let options: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            options as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess else {
            return nil
        }

        return pixelBuffer
    }

    /// Invalidate effect cache when effect stack changes
    func invalidateEffectCache() {
        videoEffectProcessor?.invalidateFilterCache()
    }
}
