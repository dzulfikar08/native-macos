import XCTest
import AVFoundation
import CoreVideo
@testable import OpenScreen

/// Tests for WipeRenderer
final class WipeRendererTests: XCTestCase {

    // MARK: - Wipe at Start Tests

    func testWipeAtStart() throws {
        let renderer = WipeRenderer()
        let transition = TransitionClip(
            type: .wipe,
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
        let leftColor = try TransitionRenderingTestHelpers.extractColorAt(from: result, x: 0.25, y: 0.5)
        XCTAssertEqual(leftColor.red, 1.0, accuracy: 0.01, "Left side should be red at progress 0.0")
    }

    // MARK: - Wipe at Midpoint Tests

    func testWipeAtMidpoint() throws {
        let renderer = WipeRenderer()
        let transition = TransitionClip(
            type: .wipe,
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

        // At progress 0.5, left half should be red (source), right half should be blue (target)
        let leftColor = try TransitionRenderingTestHelpers.extractColorAt(from: result, x: 0.25, y: 0.5)
        let rightColor = try TransitionRenderingTestHelpers.extractColorAt(from: result, x: 0.75, y: 0.5)

        XCTAssertEqual(leftColor.red, 1.0, accuracy: 0.01, "Left side should be red at progress 0.5")
        XCTAssertEqual(rightColor.blue, 1.0, accuracy: 0.01, "Right side should be blue at progress 0.5")
    }

    // MARK: - Wipe at End Tests

    func testWipeAtEnd() throws {
        let renderer = WipeRenderer()
        let transition = TransitionClip(
            type: .wipe,
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
        let rightColor = try TransitionRenderingTestHelpers.extractColorAt(from: result, x: 0.75, y: 0.5)
        XCTAssertEqual(rightColor.blue, 1.0, accuracy: 0.01, "Right side should be blue at progress 1.0")
    }

    // MARK: - Invalid Progress Tests

    func testInvalidProgressNegative() throws {
        let renderer = WipeRenderer()
        let transition = TransitionClip(
            type: .wipe,
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
        let renderer = WipeRenderer()
        let transition = TransitionClip(
            type: .wipe,
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
