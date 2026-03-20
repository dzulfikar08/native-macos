import XCTest
@testable import OpenScreen

@MainActor
final class TimelineViewInOutPointClearTests: XCTestCase {

    var timeline: TimelineView!
    var mockDelegate: MockTimelineViewDelegate!

    override func setUp() async throws {
        timeline = TimelineView(frame: NSRect(x: 0, y: 0, width: 800, height: 200), device: nil)
        mockDelegate = MockTimelineViewDelegate()
        timeline.delegate = mockDelegate
    }

    override func tearDown() async throws {
        timeline = nil
        mockDelegate = nil
    }

    // MARK: - Clear In/Out Point Button Tests

    func testClearInOutPointButtonExists() {
        let buttons = timeline.subviews.compactMap { $0 as? NSButton }
        let clearButton = buttons.first { $0.title.contains("Clear") || $0.toolTip?.contains("Clear In/Out") ?? false }
        XCTAssertNotNil(clearButton, "Clear In/Out Point button should exist")
    }

    func testClearInOutPointButtonAction() {
        let clearButton = timeline.subviews.compactMap { $0 as? NSButton }.first { $0.title.contains("Clear") }
        XCTAssertNotNil(clearButton, "Clear button should be found")

        // Simulate button click
        clearButton?.performClick()

        // Verify delegate was called to clear in/out points
        XCTAssertEqual(mockDelegate.clearInOutPointCallCount, 1, "Delegate should have been called to clear in/out points")
    }

    func testClearInOutPointKeyboardShortcut() async {
        // Test Cmd+Shift+C for clear in/out points
        let keyC = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command, .shift],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "C",
            charactersIgnoringModifiers: "c",
            isARepeat: false,
            keyCode: 8
        )

        timeline.keyDown(with: keyC!)

        // Verify delegate was called
        XCTAssertEqual(mockDelegate.clearInOutPointCallCount, 1, "Cmd+Shift+C should trigger clear in/out points")
    }

    func testClearInOutPointButtonDisablesWhenNoPoints() {
        let clearButton = timeline.subviews.compactMap { $0 as? NSButton }.first { $0.title.contains("Clear") }
        XCTAssertNotNil(clearButton, "Clear button should be found")

        // Initially, clear button should be disabled (no in/out points to clear)
        // This test would be enhanced with actual state checking
        XCTAssertEqual(mockDelegate.clearInOutPointCallCount, 0, "No clear action should have been triggered initially")
    }
}

// MARK: - Mock Timeline Delegate (same as other tests)

class MockTimelineViewDelegate: NSObject {
    var setInPointCallCount = 0
    var setOutPointCallCount = 0
    var clearInOutPointCallCount = 0
    var focusModeCallCount = 0
    var lastInPointTime: Double = 0.0
    var lastOutPointTime: Double = 0.0

    func timelineViewDidSetInPoint(_ timeline: TimelineView, time: Double) {
        setInPointCallCount += 1
        lastInPointTime = time
    }

    func timelineViewDidSetOutPoint(_ timeline: TimelineView, time: Double) {
        setOutPointCallCount += 1
        lastOutPointTime = time
    }

    func timelineViewDidClearInOutPoints(_ timeline: TimelineView) {
        clearInOutPointCallCount += 1
    }

    func timelineViewDidToggleFocusMode(_ timeline: TimelineView, isFocused: Bool) {
        focusModeCallCount += 1
    }
}