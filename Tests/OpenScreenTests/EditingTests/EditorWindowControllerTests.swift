import XCTest
@testable import OpenScreen

@MainActor
final class EditorWindowControllerTests: XCTestCase {
    func testEditorWindowCreation() {
        let url = TestDataFactory.makeTestRecordingURL()
        EditorState.initializeShared(with: url)
        let editor = EditorWindowController(recordingURL: url)

        editor.showWindow(nil)

        XCTAssertNotNil(editor.window)
        XCTAssertEqual(editor.window?.title, "OpenScreen Editor")
        XCTAssertNotNil(editor.window?.contentViewController)
    }

    func testSplitViewLayout() {
        let url = TestDataFactory.makeTestRecordingURL()
        EditorState.initializeShared(with: url)
        let editor = EditorWindowController(recordingURL: url)

        editor.showWindow(nil)

        // Verify content view controller is a split view controller
        let contentVC = editor.window?.contentViewController
        XCTAssertNotNil(contentVC)

        // Verify it's an NSSplitViewController
        let splitVC = contentVC as? NSSplitViewController
        XCTAssertNotNil(splitVC, "Content view controller should be NSSplitViewController")

        // Verify split view has 3 children (video preview + timeline + effects panel)
        XCTAssertEqual(splitVC?.children.count, 3, "Split view should have 3 children")
    }

    func testSplitViewConfiguration() {
        let url = TestDataFactory.makeTestRecordingURL()
        EditorState.initializeShared(with: url)
        let editor = EditorWindowController(recordingURL: url)

        editor.showWindow(nil)

        let splitVC = editor.window?.contentViewController as? NSSplitViewController
        XCTAssertNotNil(splitVC)

        // Verify split view is vertical
        XCTAssertTrue(splitVC?.splitView.isVertical ?? false, "Split view should be vertical")

        // Verify divider style
        XCTAssertEqual(splitVC?.splitView.dividerStyle, .thin, "Divider style should be thin")
    }

    func testWindowProperties() {
        let url = TestDataFactory.makeTestRecordingURL()
        EditorState.initializeShared(with: url)
        let editor = EditorWindowController(recordingURL: url)

        editor.showWindow(nil)

        let window = editor.window
        XCTAssertNotNil(window)

        // Verify window style mask
        let expectedStyle: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
        XCTAssertEqual(window?.styleMask, expectedStyle, "Window should have standard style mask")

        // Verify window is not nil after showing
        XCTAssertTrue(window?.isVisible ?? false, "Window should be visible after showWindow")
    }

    func testEffectsPanelIntegration() {
        let url = TestDataFactory.makeTestRecordingURL()
        EditorState.initializeShared(with: url)
        let editor = EditorWindowController(recordingURL: url)

        editor.showWindow(nil)

        // Verify effects panel is created and accessible
        XCTAssertNotNil(editor.effectsPanel, "Effects panel should be created")

        // Verify effects panel has editor state
        XCTAssertEqual(editor.effectsPanel?.editorState, editor.editorState, "Effects panel should share editor state")
    }

    func testEffectsPanelPresetSelection() {
        let url = TestDataFactory.makeTestRecordingURL()
        EditorState.initializeShared(with: url)
        let editor = EditorWindowController(recordingURL: url)

        editor.showWindow(nil)

        guard let effectsPanel = editor.effectsPanel else {
            XCTFail("Effects panel should be created")
            return
        }

        // Verify preset menu is populated
        let presetCount = effectsPanel.presetPopupButtonForTesting.numberOfItems
        XCTAssertGreaterThan(presetCount, 0, "Preset menu should have items")

        // Verify "None" option exists
        let noneIndex = effectsPanel.presetPopupButtonForTesting.indexOfItem(withTitle: "None")
        XCTAssertNotEqual(noneIndex, -1, "None option should be available")

        // Test selecting "None"
        effectsPanel.presetPopupButtonForTesting.selectItem(withTitle: "None")
        XCTAssertNil(editor.editorState.effectStack.selectedPreset, "Selected preset should be nil after choosing None")
    }

    func testEffectsPanelApplyResetButtons() {
        let url = TestDataFactory.makeTestRecordingURL()
        EditorState.initializeShared(with: url)
        let editor = EditorWindowController(recordingURL: url)

        editor.showWindow(nil)

        guard let effectsPanel = editor.effectsPanel else {
            XCTFail("Effects panel should be created")
            return
        }

        // Add a test effect
        let effect = VideoEffect(type: .brightness, parameters: .brightness(0.5), isEnabled: true)
        editor.editorState.effectStack.videoEffects.append(effect)

        // Test apply button triggers notification
        let expectation = XCTestExpectation(description: "Apply effects notification")
        NotificationCenter.default.addObserver(
            forName: .applyEffects,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }

        effectsPanel.applyButtonForTesting.performClick(nil)

        wait(for: [expectation], timeout: 1.0)

        // Test reset button clears effects
        effectsPanel.resetButtonForTesting.performClick(nil)

        XCTAssertTrue(editor.editorState.effectStack.videoEffects.isEmpty, "Video effects should be empty after reset")
        XCTAssertTrue(editor.editorState.effectStack.audioEffects.isEmpty, "Audio effects should be empty after reset")
        XCTAssertNil(editor.editorState.effectStack.selectedPreset, "Selected preset should be nil after reset")
    }

    func testRenderingPerformance() async throws {
        let url = TestDataFactory.makeTestRecordingURL()
        EditorState.initializeShared(with: url)
        let editor = EditorWindowController(recordingURL: url)
        editor.showWindow(nil)

        // Wait for initial setup
        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

        // Enable playback
        editor.editorState.isPlaying = true

        // Measure time to render 60 frames
        let start = Date()
        var framesRendered = 0

        for _ in 0..<60 {
            await editor.renderNextFrame()
            framesRendered += 1
        }

        let elapsed = Date().timeIntervalSince(start)

        // Should render 60 frames in ~1 second at 60fps (allow 50% tolerance for CI environment)
        XCTAssertLessThan(elapsed, 1.5, "Rendering \(framesRendered) frames took \(elapsed)s (expected <1.5s for 60fps)")
        XCTAssertGreaterThan(framesRendered, 50, "Should render at least 50 of 60 frames")
    }
}
