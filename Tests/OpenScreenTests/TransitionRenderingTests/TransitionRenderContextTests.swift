import XCTest
import AVFoundation
@testable import OpenScreen

/// Tests for TransitionRenderContext
final class TransitionRenderContextTests: XCTestCase {

    // MARK: - Crossfade Renderer Tests

    func testGetRendererForCrossfade() {
        let context = TransitionRenderContext()

        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )

        let renderer = context.renderer(for: transition)

        XCTAssertTrue(renderer is CrossfadeRenderer, "Expected CrossfadeRenderer for crossfade transition")
    }

    // MARK: - All Types Tests

    func testGetRendererForEachType() {
        let context = TransitionRenderContext()

        // Test crossfade returns correct renderer
        let crossfadeTransition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )
        let crossfadeRenderer = context.renderer(for: crossfadeTransition)
        XCTAssertTrue(crossfadeRenderer is CrossfadeRenderer, "Expected CrossfadeRenderer for crossfade transition")

        // Test fadeToColor returns correct renderer
        let fadeToColorTransition = TransitionClip(
            type: .fadeToColor,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )
        let fadeToColorRenderer = context.renderer(for: fadeToColorTransition)
        XCTAssertTrue(fadeToColorRenderer is FadeToColorRenderer, "Expected FadeToColorRenderer for fadeToColor transition")

        // Test wipe returns correct renderer
        let wipeTransition = TransitionClip(
            type: .wipe,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )
        let wipeRenderer = context.renderer(for: wipeTransition)
        XCTAssertTrue(wipeRenderer is WipeRenderer, "Expected WipeRenderer for wipe transition")

        // Test iris returns correct renderer
        let irisTransition = TransitionClip(
            type: .iris,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )
        let irisRenderer = context.renderer(for: irisTransition)
        XCTAssertTrue(irisRenderer is IrisRenderer, "Expected IrisRenderer for iris transition")

        // Test blinds returns correct renderer
        let blindsTransition = TransitionClip(
            type: .blinds,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )
        let blindsRenderer = context.renderer(for: blindsTransition)
        XCTAssertTrue(blindsRenderer is BlindsRenderer, "Expected BlindsRenderer for blinds transition")
    }

    // MARK: - Custom Transition Tests

    func testGetRendererForCustomReturnsCrossfade() {
        let context = TransitionRenderContext()

        // Test that custom transitions default to CrossfadeRenderer
        let customTransition = TransitionClip(
            type: .custom("MyCustomTransition"),
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )

        let renderer = context.renderer(for: customTransition)

        XCTAssertTrue(renderer is CrossfadeRenderer, "Expected CrossfadeRenderer for custom transition (defaults to crossfade)")
    }
}
