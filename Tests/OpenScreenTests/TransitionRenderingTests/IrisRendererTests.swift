import XCTest
import AVFoundation
import CoreVideo
@testable import OpenScreen

/// Tests for IrisRenderer
final class IrisRendererTests: XCTestCase {

    // MARK: - Iris at Start Tests

    func testIrisAtStart() throws {
        let renderer = IrisRenderer()
        let transition = TransitionClip(
            type: .iris,
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

        // At progress 0, should see only source (red) everywhere
        let centerColor = try TransitionRenderingTestHelpers.extractColorAt(from: result, x: 0.5, y: 0.5)
        let edgeColor = try TransitionRenderingTestHelpers.extractColorAt(from: result, x: 0.1, y: 0.1)

        XCTAssertEqual(centerColor.red, 1.0, accuracy: 0.01, "Center should be red at progress 0.0")
        XCTAssertEqual(edgeColor.red, 1.0, accuracy: 0.01, "Edge should be red at progress 0.0")
    }

    // MARK: - Iris at Midpoint Tests

    func testIrisAtMidpoint() throws {
        let renderer = IrisRenderer()
        let transition = TransitionClip(
            type: .iris,
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

        // At progress 0.5, center should show target (blue), edges should show source (red)
        let centerColor = try TransitionRenderingTestHelpers.extractColorAt(from: result, x: 0.5, y: 0.5)
        let edgeColor = try TransitionRenderingTestHelpers.extractColorAt(from: result, x: 0.1, y: 0.1)

        XCTAssertEqual(centerColor.blue, 1.0, accuracy: 0.01, "Center should be blue at progress 0.5")
        XCTAssertEqual(edgeColor.red, 1.0, accuracy: 0.01, "Edge should be red at progress 0.5")
    }

    // MARK: - Iris at End Tests

    func testIrisAtEnd() throws {
        let renderer = IrisRenderer()
        let transition = TransitionClip(
            type: .iris,
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

        // At progress 1.0, should see only target (blue) everywhere
        let centerColor = try TransitionRenderingTestHelpers.extractColorAt(from: result, x: 0.5, y: 0.5)
        let edgeColor = try TransitionRenderingTestHelpers.extractColorAt(from: result, x: 0.1, y: 0.1)

        XCTAssertEqual(centerColor.blue, 1.0, accuracy: 0.01, "Center should be blue at progress 1.0")
        XCTAssertEqual(edgeColor.blue, 1.0, accuracy: 0.01, "Edge should be blue at progress 1.0")
    }

    // MARK: - Invalid Progress Tests

    func testInvalidProgressNegative() throws {
        let renderer = IrisRenderer()
        let transition = TransitionClip(
            type: .iris,
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
        let renderer = IrisRenderer()
        let transition = TransitionClip(
            type: .iris,
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
