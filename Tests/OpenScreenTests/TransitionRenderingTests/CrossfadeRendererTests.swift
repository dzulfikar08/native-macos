import XCTest
import AVFoundation
import CoreVideo
@testable import OpenScreen

/// Tests for CrossfadeRenderer
final class CrossfadeRendererTests: XCTestCase {

    // MARK: - Crossfade at Start Tests

    func testCrossfadeAtStart() throws {
        let renderer = CrossfadeRenderer()
        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )

        let sourceBuffer = try TransitionRenderingTestHelpers.createTestPixelBuffer(color: .red)
        let targetBuffer = try TransitionRenderingTestHelpers.createTestPixelBuffer(color: .blue)

        let result = try renderer.render(
            sourceBuffer: sourceBuffer,
            targetBuffer: targetBuffer,
            progress: 0.0,
            transition: transition
        )

        // At progress 0, should see only source (red)
        let color = try TransitionRenderingTestHelpers.extractDominantColor(from: result)
        XCTAssertEqual(color.red, 1.0, accuracy: 0.01, "Should be red at progress 0.0")
    }

    // MARK: - Crossfade at Midpoint Tests

    func testCrossfadeAtMidpoint() throws {
        let renderer = CrossfadeRenderer()
        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )

        let sourceBuffer = try TransitionRenderingTestHelpers.createTestPixelBuffer(color: .red)
        let targetBuffer = try TransitionRenderingTestHelpers.createTestPixelBuffer(color: .blue)

        let result = try renderer.render(
            sourceBuffer: sourceBuffer,
            targetBuffer: targetBuffer,
            progress: 0.5,
            transition: transition
        )

        // At progress 0.5, should see blend
        let color = try TransitionRenderingTestHelpers.extractDominantColor(from: result)
        // Red and blue mixed = purple
        XCTAssertTrue(color.red > 0.3 && color.red < 0.7, "Red should be blended (0.3-0.7) at progress 0.5")
        XCTAssertTrue(color.blue > 0.3 && color.blue < 0.7, "Blue should be blended (0.3-0.7) at progress 0.5")
    }

    // MARK: - Crossfade at End Tests

    func testCrossfadeAtEnd() throws {
        let renderer = CrossfadeRenderer()
        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )

        let sourceBuffer = try TransitionRenderingTestHelpers.createTestPixelBuffer(color: .red)
        let targetBuffer = try TransitionRenderingTestHelpers.createTestPixelBuffer(color: .blue)

        let result = try renderer.render(
            sourceBuffer: sourceBuffer,
            targetBuffer: targetBuffer,
            progress: 1.0,
            transition: transition
        )

        // At progress 1, should see only target (blue)
        let color = try TransitionRenderingTestHelpers.extractDominantColor(from: result)
        XCTAssertEqual(color.blue, 1.0, accuracy: 0.01, "Should be blue at progress 1.0")
    }

    // MARK: - Invalid Progress Tests

    func testInvalidProgressNegative() throws {
        let renderer = CrossfadeRenderer()
        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )

        let sourceBuffer = try TransitionRenderingTestHelpers.createTestPixelBuffer(color: .red)
        let targetBuffer = try TransitionRenderingTestHelpers.createTestPixelBuffer(color: .blue)

        XCTAssertThrowsError(
            try renderer.render(
                sourceBuffer: sourceBuffer,
                targetBuffer: targetBuffer,
                progress: -0.1,
                transition: transition
            )
        ) { error in
            XCTAssertEqual(error as? TransitionError, .parameterOutOfRange("progress", validRange: 0.0...1.0))
        }
    }

    func testInvalidProgressGreaterThanOne() throws {
        let renderer = CrossfadeRenderer()
        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )

        let sourceBuffer = try TransitionRenderingTestHelpers.createTestPixelBuffer(color: .red)
        let targetBuffer = try TransitionRenderingTestHelpers.createTestPixelBuffer(color: .blue)

        XCTAssertThrowsError(
            try renderer.render(
                sourceBuffer: sourceBuffer,
                targetBuffer: targetBuffer,
                progress: 1.1,
                transition: transition
            )
        ) { error in
            XCTAssertEqual(error as? TransitionError, .parameterOutOfRange("progress", validRange: 0.0...1.0))
        }
    }
}
