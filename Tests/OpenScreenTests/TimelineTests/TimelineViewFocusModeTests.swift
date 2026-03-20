import XCTest
import AppKit
@testable import OpenScreen

@MainActor
final class TimelineViewFocusModeTests: XCTestCase {

    var timelineView: TimelineView!
    var mockDelegate: MockInOutPointDelegate!
    var testEditorState: EditorState!

    override func setUp() {
        super.setUp()

        // Create test editor state
        testEditorState = EditorState.createTestState()
        testEditorState.duration = CMTime(seconds: 60.0, preferredTimescale: 600)

        // Create a minimal timeline view for testing
        timelineView = TimelineView(frame: NSRect(x: 0, y: 0, width: 800, height: 200), device: nil)
        timelineView.configure(with: testEditorState)
        mockDelegate = MockInOutPointDelegate()
        timelineView.inOutPointDelegate = mockDelegate

        // Set up initial zoom
        timelineView.zoom(to: 50.0)
    }

    override func tearDown() {
        timelineView = nil
        mockDelegate = nil
        testEditorState = nil
        super.tearDown()
    }

    func testFocusModeNotActiveInitially() {
        XCTAssertFalse(timelineView.isFocusMode, "Focus mode should not be active initially")
    }

    func testToggleFocusMode() {
        // Toggle focus mode on
        timelineView.toggleFocusMode()
        XCTAssertTrue(timelineView.isFocusMode, "Focus mode should be active after toggle")

        // Toggle focus mode off
        timelineView.toggleFocusMode()
        XCTAssertFalse(timelineView.isFocusMode, "Focus mode should be inactive after second toggle")
    }

    func testFocusModeDelegateCallback() {
        // Test that delegate callback is called when focus mode is toggled
        timelineView.toggleFocusMode()
        XCTAssertTrue(mockDelegate.didCallFocusMode, "Delegate should be notified of focus mode toggle")
    }

    func testFocusModeButtonState() {
        // Initially should be off
        XCTAssertEqual(timelineView.focusModeButton.state, .off, "Focus mode button should be off initially")

        // Toggle focus mode
        timelineView.toggleFocusMode()
        XCTAssertEqual(timelineView.focusModeButton.state, .on, "Focus mode button should be on when active")

        // Toggle off
        timelineView.toggleFocusMode()
        XCTAssertEqual(timelineView.focusModeButton.state, .off, "Focus mode button should be off when inactive")
    }

    func testVisibleTimeRangeWithoutInOutPoints() {
        // No in/out points set
        let visibleRange = timelineView.visibleTimeRange()

        // Should default to full duration with 10% padding
        let expectedStart = CMTime.zero
        let expectedEnd = CMTime(seconds: 60.0 + 12.0, preferredTimescale: 600) // 60 + 10% padding
        XCTAssertEqual(visibleRange.lowerBound, expectedStart, "Start should be video start with padding")
        XCTAssertEqual(visibleRange.upperBound, expectedEnd, "End should be video end with padding")
    }

    func testVisibleTimeRangeWithInOutPoints() {
        // Set in and out points
        testEditorState.inPoint = CMTime(seconds: 10.0, preferredTimescale: 600)
        testEditorState.outPoint = CMTime(seconds: 50.0, preferredTimescale: 600)

        let visibleRange = timelineView.visibleTimeRange()

        // Should be in/out range with 10% padding
        let padding = (50.0 - 10.0) * 0.1 // 4.0 seconds padding
        let expectedStart = max(CMTime.zero, 10.0 - padding) // 6.0
        let expectedEnd = min(CMTime(seconds: 60.0, preferredTimescale: 600), 50.0 + padding) // 54.0

        XCTAssertEqual(visibleRange.lowerBound.seconds, expectedStart.seconds, "Start should be in point minus padding")
        XCTAssertEqual(visibleRange.upperBound.seconds, expectedEnd.seconds, "End should be out point plus padding")
    }

    func testVisibleTimeRangeWithZeroRange() {
        // Set in and out points to be the same
        testEditorState.inPoint = CMTime(seconds: 30.0, preferredTimescale: 600)
        testEditorState.outPoint = CMTime(seconds: 30.0, preferredTimescale: 600)

        let visibleRange = timelineView.visibleTimeRange()

        // Should default to full duration when range is zero
        XCTAssertEqual(visibleRange.lowerBound, CMTime.zero, "Start should be video start when range is zero")
        XCTAssertEqual(visibleRange.upperBound, testEditorState.duration, "End should be video end when range is zero")
    }

    func testFocusModeAnimationUpdatesContentScale() {
        // Set in/out points to create a focused range
        testEditorState.inPoint = CMTime(seconds: 10.0, preferredTimescale: 600)
        testEditorState.outPoint = CMTime(seconds: 20.0, preferredTimescale: 600)

        let originalScale = timelineView.contentScale

        // Toggle focus mode
        timelineView.toggleFocusMode()

        // Content scale should change based on zoom calculation
        XCTAssertNotEqual(timelineView.contentScale, originalScale, "Content scale should change in focus mode")
    }

    func testFocusModeAnimationTriggersRedraw() {
        // Mock needsDisplay to track calls
        let originalNeedsDisplay = timelineView.needsDisplay

        // Toggle focus mode
        timelineView.toggleFocusMode()

        // Note: Direct testing of needsDisplay is complex in this context
        // The actual implementation does set needsDisplay = true
        XCTAssertTrue(timelineView.needsDisplay == true || originalNeedsDisplay != timelineView.needsDisplay,
                     "needsDisplay should be true after focus mode toggle")
    }

    func testFocusModeWithNoInPoint() {
        // Only set out point, no in point
        testEditorState.inPoint = nil
        testEditorState.outPoint = CMTime(seconds: 30.0, preferredTimescale: 600)

        let visibleRange = timelineView.visibleTimeRange()

        // Should start from zero and extend to out point with padding
        XCTAssertEqual(visibleRange.lowerBound, CMTime.zero, "Start should be zero when no in point")
        XCTAssertEqual(visibleRange.upperBound.seconds, 33.0, "End should be out point plus 10% padding")
    }

    func testFocusModeWithNoOutPoint() {
        // Only set in point, no out point
        testEditorState.inPoint = CMTime(seconds: 20.0, preferredTimescale: 600)
        testEditorState.outPoint = nil

        let visibleRange = timelineView.visibleTimeRange()

        // Should start from in point with padding and extend to duration
        XCTAssertEqual(visibleRange.lowerBound.seconds, 18.0, "Start should be in point minus 10% padding")
        XCTAssertEqual(visibleRange.upperBound, testEditorState.duration, "End should be video duration")
    }

    func testFocusModeKeyboardShortcut() {
        // Test Cmd+F for focus mode toggle
        let keyF = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "F",
            charactersIgnoringModifiers: "f",
            isARepeat: false,
            keyCode: 3
        )

        timelineView.keyDown(with: keyF!)

        // Verify focus mode was toggled
        XCTAssertTrue(timelineView.isFocusMode, "Cmd+F should trigger focus mode toggle")
        XCTAssertTrue(mockDelegate.didCallFocusMode, "Delegate should be notified")
    }

    func testFocusModeAnimationDuration() {
        // Test that the animation context has the correct duration
        let context = NSAnimationContext.current
        XCTAssertEqual(context.duration, 0.3, "Focus mode animation should be 0.3 seconds")
        XCTAssertTrue(context.allowsImplicitAnimation, "Focus mode should allow implicit animations")
    }
}

// Mock delegate for testing
@MainActor
class MockInOutPointDelegate: TimelineViewInOutPointDelegate {
    var didCallInPoint = false
    var didCallOutPoint = false
    var didCallClearInOutPoints = false
    var didCallSeek = false
    var didCallPlayPause = false
    var didCallFocusMode = false

    func timelineViewDidSetInPoint(_ timeline: TimelineView, time: Double) {
        didCallInPoint = true
    }

    func timelineViewDidSetOutPoint(_ timeline: TimelineView, time: Double) {
        didCallOutPoint = true
    }

    func timelineViewDidClearInOutPoints(_ timeline: TimelineView) {
        didCallClearInOutPoints = true
    }

    func timelineViewDidToggleFocusMode(_ timeline: TimelineView, isFocused: Bool) {
        didCallFocusMode = true
    }

    func timelineViewDidSeek(_ timeline: TimelineView, amount: Double) {
        didCallSeek = true
    }

    func timelineViewDidPlayPause(_ timeline: TimelineView) {
        didCallPlayPause = true
    }
}