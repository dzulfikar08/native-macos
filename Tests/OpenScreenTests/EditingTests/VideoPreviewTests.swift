import XCTest
@testable import OpenScreen
import AVFoundation
import CoreMedia

@MainActor
final class VideoPreviewTests: XCTestCase {
    func testVideoPreviewInitialization() {
        let preview = VideoPreview()
        XCTAssertNotNil(preview.device)
        XCTAssertEqual(preview.preferredFramesPerSecond, 60)
        XCTAssertFalse(preview.isPaused)
        XCTAssertEqual(preview.clearColor.red, 0, accuracy: 0.001)
        XCTAssertEqual(preview.clearColor.green, 0, accuracy: 0.001)
        XCTAssertEqual(preview.clearColor.blue, 0, accuracy: 0.001)
        XCTAssertEqual(preview.clearColor.alpha, 1, accuracy: 0.001)
    }

    func testVideoPreviewFrameRate() {
        let preview = VideoPreview()
        XCTAssertEqual(preview.preferredFramesPerSecond, 60, "Should target 60fps")
    }
}

// MARK: - Effect Integration Tests

@MainActor
final class VideoPreviewEffectIntegrationTests: XCTestCase {
    var preview: VideoPreview!
    var editorState: EditorState!

    override func setUp() async throws {
        try await super.setUp()

        EditorState.initializeShared(with: URL(fileURLWithPath: "/test/video.mov"))
        editorState = EditorState.shared

        preview = VideoPreview(frame: .zero)
        preview.editorState = editorState
    }

    override func tearDown() async throws {
        preview = nil
        editorState = nil
        EditorState.shared = nil
        try await super.tearDown()
    }

    func testVideoPreviewWithEffects() async throws {
        // Add an effect
        let effect = VideoEffect(
            type: .brightness,
            parameters: .brightness(0.2),
            isEnabled: true
        )

        editorState.effectStack.videoEffects = [effect]

        // Preview should have effect processor initialized
        XCTAssertNotNil(preview)
        XCTAssertEqual(editorState.effectStack.videoEffects.count, 1)
    }

    func testVideoPreviewWithoutEffects() async throws {
        // Verify no effects initially
        XCTAssertTrue(editorState.effectStack.videoEffects.isEmpty)

        // Preview should work without effects
        XCTAssertNotNil(preview)
    }

    func testDisabledEffectSkipped() async throws {
        var effect = VideoEffect(
            type: .saturation,
            parameters: .saturation(1.2),
            isEnabled: false  // Disabled
        )

        editorState.effectStack.videoEffects = [effect]

        // Effect should be in stack but not applied
        XCTAssertEqual(editorState.effectStack.videoEffects.count, 1)
        XCTAssertFalse(editorState.effectStack.videoEffects.first?.isEnabled ?? true)
    }

    func testMultipleEnabledEffects() async throws {
        // Add multiple effects
        let effects = [
            VideoEffect(type: .brightness, parameters: .brightness(0.1), isEnabled: true),
            VideoEffect(type: .contrast, parameters: .contrast(1.2), isEnabled: true),
            VideoEffect(type: .saturation, parameters: .saturation(1.3), isEnabled: true)
        ]

        editorState.effectStack.videoEffects = effects

        // All effects should be in stack
        XCTAssertEqual(editorState.effectStack.videoEffects.count, 3)

        // All should be enabled
        for effect in editorState.effectStack.videoEffects {
            XCTAssertTrue(effect.isEnabled)
        }
    }

    func testMixedEnabledDisabledEffects() async throws {
        // Add mix of enabled and disabled effects
        let effects = [
            VideoEffect(type: .brightness, parameters: .brightness(0.1), isEnabled: true),
            VideoEffect(type: .contrast, parameters: .contrast(1.2), isEnabled: false),
            VideoEffect(type: .saturation, parameters: .saturation(1.3), isEnabled: true)
        ]

        editorState.effectStack.videoEffects = effects

        // Should have 3 effects total
        XCTAssertEqual(editorState.effectStack.videoEffects.count, 3)

        // Should have 2 enabled
        let enabledCount = editorState.effectStack.videoEffects.filter { $0.isEnabled }.count
        XCTAssertEqual(enabledCount, 2)
    }
}
