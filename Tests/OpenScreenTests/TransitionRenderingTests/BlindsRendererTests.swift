import XCTest
import AVFoundation
import CoreVideo
@testable import OpenScreen

/// Tests for BlindsRenderer
final class BlindsRendererTests: XCTestCase {

    // MARK: - Blinds at Start Tests

    func testBlindsAtStart() throws {
        let renderer = BlindsRenderer()
        let transition = TransitionClip(
            type: .blinds,
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
        let topColor = try TransitionRenderingTestHelpers.extractColorAt(from: result, x: 0.5, y: 0.1)
        let middleColor = try TransitionRenderingTestHelpers.extractColorAt(from: result, x: 0.5, y: 0.5)
        let bottomColor = try TransitionRenderingTestHelpers.extractColorAt(from: result, x: 0.5, y: 0.9)

        XCTAssertEqual(topColor.red, 1.0, accuracy: 0.01, "Top should be red at progress 0.0")
        XCTAssertEqual(middleColor.red, 1.0, accuracy: 0.01, "Middle should be red at progress 0.0")
        XCTAssertEqual(bottomColor.red, 1.0, accuracy: 0.01, "Bottom should be red at progress 0.0")
    }

    // MARK: - Blinds at Midpoint Tests

    func testBlindsAtMidpoint() throws {
        let renderer = BlindsRenderer()
        let transition = TransitionClip(
            type: .blinds,
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

        // At progress 0.5, blinds should be at different stages
        // We should see a mix of red and blue at different vertical positions
        let topColor = try TransitionRenderingTestHelpers.extractColorAt(from: result, x: 0.5, y: 0.1)
        let middleColor = try TransitionRenderingTestHelpers.extractColorAt(from: result, x: 0.5, y: 0.5)
        let bottomColor = try TransitionRenderingTestHelpers.extractColorAt(from: result, x: 0.5, y: 0.9)

        // Verify we have a mix (not all one color)
        let hasRed = topColor.red > 0.5 || middleColor.red > 0.5 || bottomColor.red > 0.5
        let hasBlue = topColor.blue > 0.5 || middleColor.blue > 0.5 || bottomColor.blue > 0.5

        XCTAssertTrue(hasRed, "Should have some red visible at progress 0.5")
        XCTAssertTrue(hasBlue, "Should have some blue visible at progress 0.5")
    }

    // MARK: - Blinds at End Tests

    func testBlindsAtEnd() throws {
        let renderer = BlindsRenderer()
        let transition = TransitionClip(
            type: .blinds,
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

        // At progress 1.0, should see only target (blue)
        let topColor = try TransitionRenderingTestHelpers.extractColorAt(from: result, x: 0.5, y: 0.1)
        let middleColor = try TransitionRenderingTestHelpers.extractColorAt(from: result, x: 0.5, y: 0.5)
        let bottomColor = try TransitionRenderingTestHelpers.extractColorAt(from: result, x: 0.5, y: 0.9)

        XCTAssertEqual(topColor.blue, 1.0, accuracy: 0.01, "Top should be blue at progress 1.0")
        XCTAssertEqual(middleColor.blue, 1.0, accuracy: 0.01, "Middle should be blue at progress 1.0")
        XCTAssertEqual(bottomColor.blue, 1.0, accuracy: 0.01, "Bottom should be blue at progress 1.0")
    }

    // MARK: - Invalid Progress Tests

    func testInvalidProgressNegative() throws {
        let renderer = BlindsRenderer()
        let transition = TransitionClip(
            type: .blinds,
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
        let renderer = BlindsRenderer()
        let transition = TransitionClip(
            type: .blinds,
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
