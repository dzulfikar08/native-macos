import Metal
import MetalKit

/// Metal renderer for video frames
@MainActor
final class MetalRenderer {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var videoPipelineState: MTLRenderPipelineState?
    private var textureCache: CVMetalTextureCache?

    init(device: MTLDevice) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        setupTextureCache()
    }

    private func setupTextureCache() {
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

    func setupPipeline(view: MTKView) throws {
        guard let library = device.makeDefaultLibrary() else {
            throw MetalError.libraryCreationFailed
        }

        guard let vertexFunction = library.makeFunction(name: "video_vertex_shader"),
              let fragmentFunction = library.makeFunction(name: "video_fragment_shader") else {
            throw MetalError.shaderCreationFailed
        }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat

        self.videoPipelineState = try device.makeRenderPipelineState(
            descriptor: pipelineDescriptor
        )
    }

    func render(texture: MTLTexture, in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let pipelineState = videoPipelineState,
              let renderPassDescriptor = view.currentRenderPassDescriptor else {
            return
        }

        let commandBuffer = commandQueue.makeCommandBuffer()
        let encoder = commandBuffer?.makeRenderCommandEncoder(
            descriptor: renderPassDescriptor
        )

        encoder?.setRenderPipelineState(pipelineState)
        encoder?.setFragmentTexture(texture, index: 0)

        // Draw fullscreen quad
        encoder?.drawPrimitives(type: MTLPrimitiveType.triangleStrip, vertexStart: 0, vertexCount: 4)

        encoder?.endEncoding()
        commandBuffer?.present(drawable)
        commandBuffer?.commit()
    }

    enum MetalError: LocalizedError {
        case libraryCreationFailed
        case shaderCreationFailed
        case pipelineCreationFailed

        var errorDescription: String? {
            switch self {
            case .libraryCreationFailed:
                return "Failed to create Metal library"
            case .shaderCreationFailed:
                return "Failed to create shader functions"
            case .pipelineCreationFailed:
                return "Failed to create render pipeline"
            }
        }
    }
}
