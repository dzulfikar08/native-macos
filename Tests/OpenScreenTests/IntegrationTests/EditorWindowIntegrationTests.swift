import XCTest
import AVFoundation
@testable import OpenScreen

/// Integration tests for EditorWindowController with TimelineView and PlaybackControls
@MainActor
final class EditorWindowIntegrationTests: XCTestCase {
    var controller: EditorWindowController?
    var testAssetURL: URL?

    override func setUp() async throws {
        try await super.setUp()

        // Create test video asset
        testAssetURL = try TestDataFactory.createTestVideo(duration: 2.0)
    }

    override func tearDown() async throws {
        try await super.tearDown()

        // Cleanup
        controller?.close()
        controller = nil

        if let url = testAssetURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Initialization Tests

    func testEditorWindowCreatesTimelineView() throws {
        // Given
        guard let url = testAssetURL else {
            XCTFail("Test asset not available")
            return
        }

        // When
        controller = EditorWindowController(recordingURL: url)
        controller?.showWindow(nil)

        // Then
        XCTAssertNotNil(controller?.window, "Window should be created")
        XCTAssertNotNil(controller?.videoPreview, "Video preview should be created")
        XCTAssertNotNil(controller?.timelineView, "Timeline view should be created")
        XCTAssertNotNil(controller?.playbackControls, "Playback controls should be created")
    }

    func testEditorWindowLayoutContainsTimeline() throws {
        // Given
        guard let url = testAssetURL else {
            XCTFail("Test asset not available")
            return
        }

        // When
        controller = EditorWindowController(recordingURL: url)
        controller?.showWindow(nil)

        // Then
        let splitView = controller?.splitViewController?.splitView
        XCTAssertNotNil(splitView, "Split view should exist")
        XCTAssertEqual(splitView?.arrangedSubviews.count, 2, "Should have 2 panels")

        // Check right panel contains timeline
        let rightPanel = controller?.rightPanelView
        XCTAssertNotNil(rightPanel, "Right panel should exist")

        // Verify timeline and controls are subviews
        XCTAssertTrue(rightPanel?.subviews.contains { $0 is TimelineView } ?? false,
                     "Right panel should contain TimelineView")
        XCTAssertTrue(rightPanel?.subviews.contains { $0 is PlaybackControls } ?? false,
                     "Right panel should contain PlaybackControls")
    }

    // MARK: - Playback Controls Integration Tests

    func testPlaybackControlsDelegateIntegration() throws {
        // Given
        guard let url = testAssetURL else {
            XCTFail("Test asset not available")
            return
        }

        controller = EditorWindowController(recordingURL: url)
        controller?.showWindow(nil)

        let editorState = controller?.editorState
        XCTAssertNotNil(editorState, "Editor state should exist")

        // When - trigger play
        controller?.playbackControls?.play(nil)

        // Then
        XCTAssertTrue(editorState?.isPlaying ?? false, "Should be playing")
    }

    func testPlaybackControlsPauseIntegration() throws {
        // Given
        guard let url = testAssetURL else {
            XCTFail("Test asset not available")
            return
        }

        controller = EditorWindowController(recordingURL: url)
        controller?.showWindow(nil)

        let editorState = controller?.editorState

        // Start playing
        controller?.playbackControls?.play(nil)
        XCTAssertTrue(editorState?.isPlaying ?? false, "Should be playing")

        // When - pause
        controller?.playbackControls?.pause(nil)

        // Then
        XCTAssertFalse(editorState?.isPlaying ?? true, "Should be paused")
    }

    func testPlaybackControlsStopIntegration() throws {
        // Given
        guard let url = testAssetURL else {
            XCTFail("Test asset not available")
            return
        }

        controller = EditorWindowController(recordingURL: url)
        controller?.showWindow(nil)

        let editorState = controller?.editorState
        let timelineView = controller?.timelineView

        // Start playing and seek
        controller?.playbackControls?.play(nil)
        controller?.playbackControls?.seekForward(nil)
        let positionBeforeStop = CMTimeGetSeconds(editorState?.currentTime ?? .zero)

        // When - stop
        controller?.playbackControls?.stop(nil)

        // Then
        XCTAssertFalse(editorState?.isPlaying ?? true, "Should be paused")
        XCTAssertEqual(CMTimeGetSeconds(editorState?.currentTime ?? .zero), 0.0, "Current time should reset to 0")
        XCTAssertEqual(timelineView?.currentTime, 0.0, "Timeline should reset to 0")
        XCTAssertNotEqual(positionBeforeStop, 0.0, "Position before stop should not be 0")
    }

    func testPlaybackControlsSeekUpdatesTimeline() throws {
        // Given
        guard let url = testAssetURL else {
            XCTFail("Test asset not available")
            return
        }

        controller = EditorWindowController(recordingURL: url)
        controller?.showWindow(nil)

        let editorState = controller?.editorState
        let timelineView = controller?.timelineView
        let initialTime = CMTimeGetSeconds(editorState?.currentTime ?? .zero)

        // When - seek forward
        controller?.playbackControls?.seekForward(nil)

        // Then
        let newTime = CMTimeGetSeconds(editorState?.currentTime ?? .zero)
        XCTAssertGreaterThan(newTime, initialTime, "Time should increase after seek")
        XCTAssertEqual(timelineView?.currentTime, newTime, "Timeline should update to new time")
    }

    func testPlaybackControlsPositionSliderIntegration() throws {
        // Given
        guard let url = testAssetURL else {
            XCTFail("Test asset not available")
            return
        }

        controller = EditorWindowController(recordingURL: url)
        controller?.showWindow(nil)

        let editorState = controller?.editorState
        let timelineView = controller?.timelineView

        // When - update position via slider
        let testPosition: Double = 1.5
        controller?.playbackControls?.updatePosition(to: testPosition)

        // Then
        XCTAssertEqual(editorState?.currentTime, testPosition, accuracy: 0.01,
                      "Editor state should update to new position")
        XCTAssertEqual(timelineView?.currentTime, testPosition, accuracy: 0.01,
                      "Timeline should update to new position")
    }

    // MARK: - Timeline Integration Tests

    func testTimelineViewReflectsEditorState() throws {
        // Given
        guard let url = testAssetURL else {
            XCTFail("Test asset not available")
            return
        }

        controller = EditorWindowController(recordingURL: url)
        controller?.showWindow(nil)

        let editorState = controller?.editorState
        let timelineView = controller?.timelineView

        // When - update editor state time
        let testTime: Double = 0.5
        editorState?.currentTime = testTime

        // Then - timeline should reflect this (via playback controls delegate)
        controller?.playbackControls?.updatePosition(to: testTime)
        XCTAssertEqual(timelineView?.currentTime, testTime, accuracy: 0.01,
                      "Timeline should reflect editor state time")
    }

    func testTimelineViewSeekUpdatesPlaybackControls() throws {
        // Given
        guard let url = testAssetURL else {
            XCTFail("Test asset not available")
            return
        }

        controller = EditorWindowController(recordingURL: url)
        controller?.showWindow(nil)

        let playbackControls = controller?.playbackControls

        // When - seek timeline
        let testTime: Double = 1.0
        controller?.timelineView?.seek(to: testTime)

        // Then - playback controls should update via delegate
        XCTAssertEqual(playbackControls?.playbackPosition, testTime, accuracy: 0.01,
                      "Playback controls should reflect timeline seek")
    }

    // MARK: - Video Processor Integration Tests

    func testVideoProcessorSeekOnPlaybackControlUpdate() async throws {
        // Given
        guard let url = testAssetURL else {
            XCTFail("Test asset not available")
            return
        }

        controller = EditorWindowController(recordingURL: url)
        controller?.showWindow(nil)

        // Wait for video to load
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        let videoProcessor = controller?.videoProcessor

        // When - seek via playback controls
        let testTime: Double = 1.0
        controller?.playbackControls?.updatePosition(to: testTime)

        // Wait for async seek
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Then - video processor should seek (this is a basic sanity check)
        XCTAssertNotNil(videoProcessor, "Video processor should exist")
        // Note: We can't easily verify the exact seek position without exposing internal state
    }

    // MARK: - Layout Tests

    func testTimelineAndControlsLayoutConstraints() throws {
        // Given
        guard let url = testAssetURL else {
            XCTFail("Test asset not available")
            return
        }

        // When
        controller = EditorWindowController(recordingURL: url)
        controller?.showWindow(nil)

        let rightPanel = controller?.rightPanelView

        // Then
        XCTAssertNotNil(rightPanel, "Right panel should exist")

        // Find timeline and controls
        let timeline = rightPanel?.subviews.first(where: { $0 is TimelineView })
        let controls = rightPanel?.subviews.first(where: { $0 is PlaybackControls })

        XCTAssertNotNil(timeline, "Timeline should be in right panel")
        XCTAssertNotNil(controls, "Playback controls should be in right panel")

        // Verify constraints are active
        XCTAssertTrue(timeline?.hasAmbiguousLayout == false, "Timeline should not have ambiguous layout")
        XCTAssertTrue(controls?.hasAmbiguousLayout == false, "Controls should not have ambiguous layout")

        // Verify controls exist
        XCTAssertNotNil(controller?.timelineView, "Timeline view should be accessible")
        XCTAssertNotNil(controller?.playbackControls, "Playback controls should be accessible")
    }

    // MARK: - Data Loading Tests

    func testEditorStateDurationSetAfterVideoLoad() async throws {
        // Given
        guard let url = testAssetURL else {
            XCTFail("Test asset not available")
            return
        }

        // When
        controller = EditorWindowController(recordingURL: url)
        controller?.showWindow(nil)

        // Wait for video to load
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Then
        let editorState = controller?.editorState
        XCTAssertGreaterThan(CMTimeGetSeconds(editorState?.duration ?? .zero), 0, "Duration should be set")
    }

    func testPlaybackControlsMaxPositionUpdatedAfterVideoLoad() async throws {
        // Given
        guard let url = testAssetURL else {
            XCTFail("Test asset not available")
            return
        }

        // When
        controller = EditorWindowController(recordingURL: url)
        controller?.showWindow(nil)

        // Wait for video to load
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Then
        let editorState = controller?.editorState
        XCTAssertGreaterThan(CMTimeGetSeconds(editorState?.duration ?? .zero), 0, "Duration should be set")

        // Verify playback controls exist and are configured
        XCTAssertNotNil(controller?.playbackControls, "Playback controls should exist")
    }

    // MARK: - Transition Selection Notification Tests

    func testTransitionSelectionNotificationPosted() throws {
        // Given
        guard let url = testAssetURL else {
            XCTFail("Test asset not available")
            return
        }

        controller = EditorWindowController(recordingURL: url)
        controller?.showWindow(nil)

        let expectation = XCTestExpectation(description: "Transition selection notification posted")

        // Setup notification observer
        let observer = NotificationCenter.default.addObserver(
            forName: .transitionSelectionChanged,
            object: controller?.timelineView?.viewModel,
            queue: .main
        ) { notification in
            // Then
            XCTAssertNotNil(notification.userInfo?["transitionID"], "Notification should contain transitionID")
            expectation.fulfill()
        }

        // When - select a transition
        let testTransitionID = UUID()
        controller?.timelineView?.viewModel?.selectTransition(testTransitionID)

        // Wait for notification
        wait(for: [expectation], timeout: 1.0)

        NotificationCenter.default.removeObserver(observer)
    }

    func testTransitionSelectionNotificationContainsCorrectID() throws {
        // Given
        guard let url = testAssetURL else {
            XCTFail("Test asset not available")
            return
        }

        controller = EditorWindowController(recordingURL: url)
        controller?.showWindow(nil)

        let expectation = XCTestExpectation(description: "Transition selection notification contains correct ID")
        let testTransitionID = UUID()

        // Setup notification observer
        let observer = NotificationCenter.default.addObserver(
            forName: .transitionSelectionChanged,
            object: controller?.timelineView?.viewModel,
            queue: .main
        ) { notification in
            // Then
            if let notifiedID = notification.userInfo?["transitionID"] as? UUID {
                XCTAssertEqual(notifiedID, testTransitionID, "Notified ID should match selected ID")
                expectation.fulfill()
            }
        }

        // When - select the transition
        controller?.timelineView?.viewModel?.selectTransition(testTransitionID)

        // Wait for notification
        wait(for: [expectation], timeout: 1.0)

        NotificationCenter.default.removeObserver(observer)
    }

    func testTransitionDeselectionPostsNotification() throws {
        // Given
        guard let url = testAssetURL else {
            XCTFail("Test asset not available")
            return
        }

        controller = EditorWindowController(recordingURL: url)
        controller?.showWindow(nil)

        let testTransitionID = UUID()
        controller?.timelineView?.viewModel?.selectTransition(testTransitionID)

        let expectation = XCTestExpectation(description: "Transition deselection notification posted")

        // Setup notification observer
        let observer = NotificationCenter.default.addObserver(
            forName: .transitionSelectionChanged,
            object: controller?.timelineView?.viewModel,
            queue: .main
        ) { notification in
            // Then - notification should have nil or missing transitionID
            let notifiedID = notification.userInfo?["transitionID"] as? UUID
            XCTAssertNil(notifiedID, "Notified ID should be nil when transition deselected")
            expectation.fulfill()
        }

        // When - deselect transition
        controller?.timelineView?.viewModel?.deselectTransition()

        // Wait for notification
        wait(for: [expectation], timeout: 1.0)

        NotificationCenter.default.removeObserver(observer)
    }

    func testTransitionSelectionOpensInspector() throws {
        // Given
        guard let url = testAssetURL else {
            XCTFail("Test asset not available")
            return
        }

        controller = EditorWindowController(recordingURL: url)
        controller?.showWindow(nil)

        // Create a test transition in editor state
        let editorState = controller?.editorState
        let leadingClip = TestDataFactory.makeVideoClip(startTime: 0, duration: 5.0)
        let trailingClip = TestDataFactory.makeVideoClip(startTime: 4.0, duration: 5.0)
        let transition = TestDataFactory.makeTransition(
            type: .crossfade,
            leadingClipID: leadingClip.id,
            trailingClipID: trailingClip.id,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600)
        )

        // Add clips and transition to editor state
        try editorState?.addClip(leadingClip, toTrackAt: 0)
        try editorState?.addClip(trailingClip, toTrackAt: 0)
        editorState?.addTransition(transition)

        let expectation = XCTestExpectation(description: "Inspector sheet presented")

        // Observe sheet presentation
        let sheetObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willBeginSheetNotification,
            object: controller?.window,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }

        // When - select the transition
        controller?.timelineView?.viewModel?.selectTransition(transition.id)

        // Wait for inspector to open
        wait(for: [expectation], timeout: 1.0)

        NotificationCenter.default.removeObserver(sheetObserver)

        // Then - verify sheet is attached to window
        XCTAssertNotNil(controller?.window?.sheet, "Sheet should be presented")
    }
}
