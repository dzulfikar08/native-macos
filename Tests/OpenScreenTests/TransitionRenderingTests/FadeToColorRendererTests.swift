import XCTest
import AVFoundation
import CoreVideo
@testable import OpenScreen

/// Tests for FadeToColorRenderer
final class FadeToColorRendererTests: XCTestCase {

    // MARK: - Fade to Black Tests

    func testFadeToBlackAtMidpoint() throws {
        let renderer = FadeToColorRenderer()

        let params = TransitionParameters.fadeToColor(color: .black, holdDuration: 0.5)
        let transition = TransitionClip(
            type: .fadeToColor,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID(),
            parameters: params
        )

        let sourceBuffer = try TransitionRenderingTestHelpers.createTestPixelBuffer(color: .white)
        let targetBuffer = try TransitionRenderingTestHelpers.createTestPixelBuffer(color: .white)

        let result = try renderer.render(
            sourceBuffer: sourceBuffer,
            targetBuffer: targetBuffer,
            progress: 0.5,
            transition: transition
        )

        // At midpoint, should be faded to black
        let luminance = try TransitionRenderingTestHelpers.extractLuminance(from: result)
        XCTAssertEqual(luminance, 0.0, accuracy: 0.1, "Should be black at midpoint")
    }

    func testFadeToBlackAtStart() throws {
        let renderer = FadeToColorRenderer()

        let params = TransitionParameters.fadeToColor(color: .black, holdDuration: 0.5)
        let transition = TransitionClip(
            type: .fadeToColor,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID(),
            parameters: params
        )

        let sourceBuffer = try TransitionRenderingTestHelpers.createTestPixelBuffer(color: .white)
        let targetBuffer = try TransitionRenderingTestHelpers.createTestPixelBuffer(color: .black)

        let result = try renderer.render(
            sourceBuffer: sourceBuffer,
            targetBuffer: targetBuffer,
            progress: 0.0,
            transition: transition
        )

        // At start, should show source (white)
        let luminance = try TransitionRenderingTestHelpers.extractLuminance(from: result)
        XCTAssertEqual(luminance, 1.0, accuracy: 0.1, "Should be white at start")
    }

    func testFadeToBlackAtEnd() throws {
        let renderer = FadeToColorRenderer()

        let params = TransitionParameters.fadeToColor(color: .black, holdDuration: 0.5)
        let transition = TransitionClip(
            type: .fadeToColor,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID(),
            parameters: params
        )

        let sourceBuffer = try TransitionRenderingTestHelpers.createTestPixelBuffer(color: .black)
        let targetBuffer = try TransitionRenderingTestHelpers.createTestPixelBuffer(color: .white)

        let result = try renderer.render(
            sourceBuffer: sourceBuffer,
            targetBuffer: targetBuffer,
            progress: 1.0,
            transition: transition
        )

        // At end, should show target (white)
        let luminance = try TransitionRenderingTestHelpers.extractLuminance(from: result)
        XCTAssertEqual(luminance, 1.0, accuracy: 0.1, "Should be white at end")
    }

    // MARK: - Fade to White Tests

    func testFadeToWhiteAtMidpoint() throws {
        let renderer = FadeToColorRenderer()

        let params = TransitionParameters.fadeToColor(color: .white, holdDuration: 0.5)
        let transition = TransitionClip(
            type: .fadeToColor,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID(),
            parameters: params
        )

        let sourceBuffer = try TransitionRenderingTestHelpers.createTestPixelBuffer(color: .black)
        let targetBuffer = try TransitionRenderingTestHelpers.createTestPixelBuffer(color: .black)

        let result = try renderer.render(
            sourceBuffer: sourceBuffer,
            targetBuffer: targetBuffer,
            progress: 0.5,
            transition: transition
        )

        // At midpoint, should be faded to white
        let luminance = try TransitionRenderingTestHelpers.extractLuminance(from: result)
        XCTAssertEqual(luminance, 1.0, accuracy: 0.1, "Should be white at midpoint")
    }

    // MARK: - Invalid Parameters Tests

    func testInvalidParametersThrowsError() throws {
        let renderer = FadeToColorRenderer()

        // Create transition with wrong parameter type
        let transition = TransitionClip(
            type: .crossfade, // Wrong type for FadeToColorRenderer
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID(),
            parameters: .crossfade
        )

        let sourceBuffer = try TransitionRenderingTestHelpers.createTestPixelBuffer(color: .white)
        let targetBuffer = try TransitionRenderingTestHelpers.createTestPixelBuffer(color: .white)

        XCTAssertThrowsError(
            try renderer.render(
                sourceBuffer: sourceBuffer,
                targetBuffer: targetBuffer,
                progress: 0.5,
                transition: transition
            )
        ) { error in
            XCTAssertTrue(error is TransitionError, "Should throw TransitionError")
        }
    }
}
