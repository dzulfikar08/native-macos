import AVFoundation
import CoreMedia
import Foundation

/// AVVideoCompositing implementation that renders transitions during export
///
/// This compositor bridges AVFoundation's export system with our transition renderers.
/// It extracts transition metadata from instruction userInfo and delegates rendering
/// to the appropriate TransitionRenderer.
///
/// NOTE: Cannot use @MainActor because AVFoundation calls compositor from background threads.
/// All methods must be thread-safe.
final class TransitionVideoCompositor: NSObject, AVVideoCompositing {

    // MARK: - Properties

    // Thread-safe renderer cache
    private var rendererCache: [String: TransitionRenderer] = [:]
    private let cacheLock = NSLock()

    // MARK: - Initialization

    /// Default initializer required by AVFoundation
    override init() {
        super.init()
    }

    // MARK: - Static State Management

    /// Called by export pipeline before composition starts
    /// - Parameter state: The editor state containing transitions
    @MainActor
    static func setEditorState(_ state: EditorState) {
        _editorState = state
        // Cache transitions for thread-safe access
        _transitionsLock.lock()
        _transitionsCache = state.transitions
        _transitionsLock.unlock()
    }

    /// Called after export completes
    static func clearEditorState() {
        _editorState = nil
        _transitionsLock.lock()
        _transitionsCache = []
        _transitionsLock.unlock()
    }

    /// Thread-safe getter for cached transitions
    /// - Returns: Cached transitions array
    private static func getTransitions() -> [TransitionClip] {
        _transitionsLock.lock()
        defer { _transitionsLock.unlock() }
        return _transitionsCache
    }

    /// Thread-safe getter for editor state
    /// - Returns: The current editor state, if set
    private static func getEditorState() -> EditorState? {
        // Synchronous access needed for AVFoundation callback
        // We use a simple lock-based approach for this
        return _editorState
    }

    // Synchronous storage for immediate access (used in AVFoundation callbacks)
    private static let _lock = NSLock()
    private static var _editorState: EditorState? {
        get {
            _lock.lock()
            defer { _lock.unlock() }
            return __editorState
        }
        set {
            _lock.lock()
            defer { _lock.unlock() }
            __editorState = newValue
        }
    }
    private nonisolated(unsafe) static var __editorState: EditorState?

    // Store a copy of transitions for thread-safe access
    private nonisolated(unsafe) static var _transitionsCache: [TransitionClip] = []
    private static let _transitionsLock = NSLock()

    // MARK: - AVVideoCompositing

    /// Pixel buffer attributes for output frames
    var pixelBufferAttributes: [String: any Sendable]? {
        return [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
    }

    /// Required pixel buffer attributes for input frames (source tracks)
    var sourcePixelBufferAttributes: [String: any Sendable]? {
        return [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB
        ]
    }

    /// Required pixel buffer attributes for render context
    var requiredPixelBufferAttributesForRenderContext: [String: any Sendable] {
        return [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB
        ]
    }

    /// Called when render context changes (no-op for now)
    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
        // No action needed - we don't cache render context
    }

    /// Main entry point for rendering a frame
    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        do {
            // Get editor state from thread-safe storage
            guard let state = Self.getEditorState() else {
                throw TransitionError.invalidParameters(reason: "EditorState not set")
            }

            // Extract transition metadata from custom instruction
            guard let instruction = request.videoCompositionInstruction as? TransitionVideoCompositionInstruction else {
                throw TransitionError.invalidParameters(
                    reason: "Instruction is not TransitionVideoCompositionInstruction"
                )
            }

            // Look up transition by ID from cached transitions
            let transitions = Self.getTransitions()
            guard let transition = transitions.first(where: { $0.id == instruction.transitionID }) else {
                throw TransitionError.clipsNotFound(
                    leadingClipID: instruction.transitionID,
                    trailingClipID: nil
                )
            }

            // Fetch source frames from tracks
            guard let leadingBuffer = request.sourceFrame(byTrackID: instruction.leadingTrackID) else {
                throw TransitionError.clipsNotFound(
                    leadingClipID: transition.leadingClipID,
                    trailingClipID: nil
                )
            }

            guard let trailingBuffer = request.sourceFrame(byTrackID: instruction.trailingTrackID) else {
                throw TransitionError.clipsNotFound(
                    leadingClipID: nil,
                    trailingClipID: transition.trailingClipID
                )
            }

            // Calculate progress through transition
            let progress = calculateProgress(
                for: request.compositionTime,
                transitionStart: instruction.transitionStart,
                transitionDuration: instruction.transitionDuration
            )

            // Get renderer for this transition type (thread-safe)
            let renderer = getRenderer(for: transition)

            // Render the transition
            let outputBuffer = try renderer.render(
                sourceBuffer: leadingBuffer,
                targetBuffer: trailingBuffer,
                progress: progress,
                transition: transition
            )

            // Finish the request with rendered frame
            request.finish(withComposedVideoFrame: outputBuffer)

        } catch {
            // Finish with error if anything goes wrong
            request.finish(with: error)
        }
    }

    /// Cancel all pending requests
    func cancelAllPendingRequestsWithAnimation() {
        // No-op - we handle requests synchronously
    }

    // MARK: - Private Methods

    /// Thread-safe renderer getter with caching
    /// - Parameter transition: The transition to render
    /// - Returns: Renderer for the transition type
    private func getRenderer(for transition: TransitionClip) -> TransitionRenderer {
        let typeKey = transition.type.rawValue

        cacheLock.lock()
        if let cached = rendererCache[typeKey] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        // Create new renderer based on type
        let renderer: TransitionRenderer
        switch transition.type {
        case .crossfade:
            renderer = CrossfadeRenderer()
        case .fadeToColor:
            renderer = FadeToColorRenderer()
        case .wipe:
            renderer = WipeRenderer()
        case .iris:
            renderer = IrisRenderer()
        case .blinds:
            renderer = BlindsRenderer()
        case .custom:
            renderer = CrossfadeRenderer() // Default to crossfade for custom
        }

        // Cache for future use
        cacheLock.lock()
        rendererCache[typeKey] = renderer
        cacheLock.unlock()

        return renderer
    }

    /// Calculates progress through transition [0.0, 1.0]
    /// - Parameters:
    ///   - compositionTime: Current render time
    ///   - transitionStart: Start time of transition
    ///   - transitionDuration: Duration of transition
    /// - Returns: Progress clamped to [0.0, 1.0]
    private func calculateProgress(
        for compositionTime: CMTime,
        transitionStart: CMTime,
        transitionDuration: CMTime
    ) -> Double {
        let elapsed = CMTimeGetSeconds(CMTimeSubtract(compositionTime, transitionStart))
        let duration = CMTimeGetSeconds(transitionDuration)

        let progress = elapsed / duration

        // Clamp to [0.0, 1.0]
        return max(0.0, min(1.0, progress))
    }
}

