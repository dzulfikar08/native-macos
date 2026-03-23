import XCTest
import AVFoundation
import CoreMedia
import CoreVideo
@testable import OpenScreen

final class TransitionVideoCompositorTests: XCTestCase {

    // MARK: - Test Properties

    private var editorState: EditorState!
    private var compositor: TransitionVideoCompositor!
    private var transition: TransitionClip!
    private var leadingClip: TestVideoClip!
    private var trailingClip: TestVideoClip!

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()

        // Clear any previous editor state
        TransitionVideoCompositor.clearEditorState()

        // Create test editor state
        editorState = EditorState.createTestState()

        // Create two overlapping clips
        let clip1ID = UUID()
        let clip2ID = UUID()

        leadingClip = TestVideoClip(
            id: clip1ID,
            timeRangeInTimeline: CMTimeRange(
                start: CMTime(seconds: 0, preferredTimescale: 600),
                end: CMTime(seconds: 3, preferredTimescale: 600)
            )
        )

        trailingClip = TestVideoClip(
            id: clip2ID,
            timeRangeInTimeline: CMTimeRange(
                start: CMTime(seconds: 2, preferredTimescale: 600), // 1 second overlap
                end: CMTime(seconds: 5, preferredTimescale: 600)
            )
        )

        // Create crossfade transition
        transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1, preferredTimescale: 600),
            leadingClipID: clip1ID,
            trailingClipID: clip2ID
        )

        // Add transition to editor state
        editorState.addTransition(transition)

        // Set editor state for compositor to access
        TransitionVideoCompositor.setEditorState(editorState)

        // Create compositor with default initializer
        compositor = TransitionVideoCompositor()
    }

    override func tearDown() async throws {
        // Clean up editor state
        TransitionVideoCompositor.clearEditorState()
        editorState = nil
        compositor = nil
        transition = nil
        leadingClip = nil
        trailingClip = nil
        try await super.tearDown()
    }

    // MARK: - Protocol Conformance Tests

    func testCompositorConformsToAVVideoCompositing() {
        // Verify compositor conforms to AVVideoCompositing protocol
        XCTAssertTrue(
            compositor is AVVideoCompositing,
            "TransitionVideoCompositor should conform to AVVideoCompositing"
        )
    }

    func testPixelBufferAttributes() {
        let attributes = compositor.pixelBufferAttributes

        // Verify 32ARGB format
        let pixelFormat = attributes[kCVPixelBufferPixelFormatTypeKey as String] as? UInt32
        XCTAssertEqual(
            pixelFormat,
            kCVPixelFormatType_32ARGB,
            "Pixel format should be 32ARGB"
        )

        // Verify Metal compatibility
        let metalCompatibility = attributes[kCVPixelBufferMetalCompatibilityKey as String] as? Bool
        XCTAssertTrue(
            metalCompatibility == true,
            "Pixel buffer should be Metal compatible"
        )
    }

    func testRequiredPixelBufferAttributes() {
        let renderContext = makeMockRenderContext()

        let attributes = compositor.requiredPixelBufferAttributes(forRenderContext: renderContext)

        // Verify 32ARGB format
        let pixelFormat = attributes[kCVPixelBufferPixelFormatTypeKey as String] as? UInt32
        XCTAssertEqual(
            pixelFormat,
            kCVPixelFormatType_32ARGB,
            "Required pixel format should be 32ARGB"
        )
    }

    func testRenderContextAssignment() {
        let renderContext = makeMockRenderContext()

        // This should not throw
        XCTAssertNoThrow(
            compositor.renderContextChanged(renderContext),
            "renderContextChanged should accept valid render context"
        )
    }

    // MARK: - Rendering Tests

    func testCrossfadeRenderingAtMidpoint() async throws {
        // Create mock request with midpoint progress
        let request = MockAsynchronousVideoCompositionRequest(
            transition: transition,
            renderTime: CMTime(seconds: 2.5, preferredTimescale: 600), // Midpoint of transition
            leadingBuffer: try createTestPixelBuffer(color: .red),
            trailingBuffer: try createTestPixelBuffer(color: .blue),
            renderContext: makeMockRenderContext()
        )

        // Execute rendering
        compositor.startRequest(request)

        // Wait for async rendering to complete
        try await request.waitForCompletion()

        // Verify request was finished
        XCTAssertTrue(request.didFinish, "Request should be finished")

        // Verify output buffer was set
        XCTAssertNotNil(request.renderedBuffer, "Output buffer should be set")

        // Verify output is a blend (not pure red or blue)
        let outputColor = try TransitionRenderingTestHelpers.extractDominantColor(
            from: request.renderedBuffer!
        )

        // At midpoint, should be roughly equal blend
        let luminance = try TransitionRenderingTestHelpers.extractLuminance(
            from: request.renderedBuffer!
        )

        // Crossfade at 0.5 progress should have luminance between red (0.299) and blue (0.114)
        XCTAssertGreaterThan(
            luminance,
            0.15,
            "Luminance should be greater than blue's 0.114"
        )
        XCTAssertLessThan(
            luminance,
            0.25,
            "Luminance should be less than red's 0.299"
        )
    }

    func testProgressCalculationAtStart() async throws {
        // Create request at start of transition (should have progress = 0.0)
        let request = MockAsynchronousVideoCompositionRequest(
            transition: transition,
            renderTime: CMTime(seconds: 2.0, preferredTimescale: 600), // Start of transition
            leadingBuffer: try createTestPixelBuffer(color: .red),
            trailingBuffer: try createTestPixelBuffer(color: .blue),
            renderContext: makeMockRenderContext()
        )

        compositor.startRequest(request)

        // Wait for async rendering to complete
        try await request.waitForCompletion()

        // At progress 0.0, output should match leading buffer (red)
        let outputColor = try TransitionRenderingTestHelpers.extractDominantColor(
            from: request.renderedBuffer!
        )

        XCTAssertGreaterThan(
            outputColor.red,
            0.9,
            "At progress 0.0, output should be mostly red (leading clip)"
        )
        XCTAssertLessThan(
            outputColor.blue,
            0.1,
            "At progress 0.0, output should have minimal blue"
        )
    }

    func testProgressCalculationAtEnd() async throws {
        // Create request at end of transition (should have progress = 1.0)
        let request = MockAsynchronousVideoCompositionRequest(
            transition: transition,
            renderTime: CMTime(seconds: 3.0, preferredTimescale: 600), // End of transition
            leadingBuffer: try createTestPixelBuffer(color: .red),
            trailingBuffer: try createTestPixelBuffer(color: .blue),
            renderContext: makeMockRenderContext()
        )

        compositor.startRequest(request)

        // Wait for async rendering to complete
        try await request.waitForCompletion()

        // At progress 1.0, output should match trailing buffer (blue)
        let outputColor = try TransitionRenderingTestHelpers.extractDominantColor(
            from: request.renderedBuffer!
        )

        XCTAssertLessThan(
            outputColor.red,
            0.1,
            "At progress 1.0, output should have minimal red"
        )
        XCTAssertGreaterThan(
            outputColor.blue,
            0.9,
            "At progress 1.0, output should be mostly blue (trailing clip)"
        )
    }

    func testMissingLeadingClipThrows() async throws {
        // Create request with missing leading clip buffer
        let request = MockAsynchronousVideoCompositionRequest(
            transition: transition,
            renderTime: CMTime(seconds: 2.5, preferredTimescale: 600),
            leadingBuffer: nil, // Missing leading clip
            trailingBuffer: try createTestPixelBuffer(color: .blue),
            renderContext: makeMockRenderContext()
        )

        // Execute rendering
        compositor.startRequest(request)

        // Wait for async rendering to complete
        try await request.waitForCompletion()

        // Verify request failed
        XCTAssertTrue(request.didFail, "Request should have failed")
        XCTAssertNotNil(request.failureError, "Should have error set")

        // Verify error type
        if let error = request.failureError {
            XCTAssertTrue(
                error is TransitionError,
                "Should throw TransitionError for missing leading clip"
            )
        }
    }

    // MARK: - Helper Methods

    private func createTestPixelBuffer(color: TestColor) throws -> CVPixelBuffer {
        return try TransitionRenderingTestHelpers.createTestPixelBuffer(
            width: 1920,
            height: 1080,
            color: color
        )
    }

    private func makeMockRenderContext() -> AVVideoCompositionRenderContext {
        let size = CGSize(width: 1920, height: 1080)

        // Create a mock render context
        let context = AVVideoCompositionRenderContext(
            size: size,
            pixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferMetalCompatibilityKey as String: true
            ] as [String: Any],
            edgeWidth: 0
        )

        return context
    }
}

// MARK: - Mock Asynchronous Video Composition Request

/// Mock implementation of AVAsynchronousVideoCompositionRequest for testing
final class MockAsynchronousVideoCompositionRequest: NSObject,
    AVAsynchronousVideoCompositionRequesting {

    let transition: TransitionClip
    let renderTime: CMTime
    let leadingBuffer: CVPixelBuffer?
    let trailingBuffer: CVPixelBuffer?
    private let context: AVVideoCompositionRenderContext

    var renderedBuffer: CVPixelBuffer?
    private(set) var didFinish = false
    private(set) var didFail = false
    private(set) var failureError: Error?

    /// Continuation for waiting on async completion
    private var continuation: CheckedContinuation<Void, Never>?

    init(
        transition: TransitionClip,
        renderTime: CMTime,
        leadingBuffer: CVPixelBuffer?,
        trailingBuffer: CVPixelBuffer?,
        renderContext: AVVideoCompositionRenderContext
    ) {
        self.transition = transition
        self.renderTime = renderTime
        self.leadingBuffer = leadingBuffer
        self.trailingBuffer = trailingBuffer
        self.context = renderContext
        super.init()
    }

    // MARK: - AVAsynchronousVideoCompositionRequesting

    var renderContext: AVVideoCompositionRenderContext {
        return context
    }

    var videoCompositionInstruction: AVVideoCompositionInstruction {
        // Create a mock instruction with transition metadata
        return TransitionVideoCompositionInstruction(
            transitionID: transition.id,
            transitionType: transition.type.rawValue,
            transitionStart: CMTime(seconds: 2.0, preferredTimescale: 600),
            transitionDuration: transition.duration,
            leadingTrackID: CMPersistentTrackID(1),
            trailingTrackID: CMPersistentTrackID(2)
        )
    }

    func sourceFrame(byTrackID trackID: CMPersistentTrackID) -> CVPixelBuffer? {
        switch trackID {
        case 1:
            return leadingBuffer
        case 2:
            return trailingBuffer
        default:
            return nil
        }
    }

    // MARK: - Request Completion

    func finish(withComposedVideoFrame renderedFrame: CVPixelBuffer) {
        renderedBuffer = renderedFrame
        didFinish = true
        continuation?.resume()
    }

    func finish(with error: Error) {
        failureError = error
        didFail = true
        continuation?.resume()
    }

    func finishCancelledRequest() {
        didFinish = true
        continuation?.resume()
    }

    /// Waits for the request to complete (success or failure)
    func waitForCompletion() async throws {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }
}

// MARK: - Test Video Clip Model

/// Simple test video clip model
struct TestVideoClip {
    let id: UUID
    let timeRangeInTimeline: CMTimeRange
}
