import XCTest
@testable import OpenScreen

@MainActor
final class TimelineViewInPointTests: XCTestCase {

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

    // MARK: - In Point Button Tests

    func testInPointButtonExists() {
        let buttons = timeline.subviews.compactMap { $0 as? NSButton }
        let inPointButton = buttons.first { $0.title == "I" || $0.toolTip?.contains("Set In Point") ?? false }
        XCTAssertNotNil(inPointButton, "In Point button should exist")
    }

    func testInPointButtonAction() {
        let inPointButton = timeline.subviews.compactMap { $0 as? NSButton }.first { $0.title == "I" }
        XCTAssertNotNil(inPointButton, "In Point button should be found")

        // Set current time to 5 seconds
        timeline.currentTime = 5.0

        // Simulate button click
        inPointButton?.performClick()

        // Verify delegate was called to set in point
        XCTAssertEqual(mockDelegate.setInPointCallCount, 1, "Delegate should have been called to set in point")
        XCTAssertEqual(mockDelegate.lastInPointTime, 5.0, "In point should be set to current time (5.0)")
    }

    func testInPointKeyboardShortcut() async {
        // Set current time
        timeline.currentTime = 5.0

        // Test I key for set in point
        let keyI = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "i",
            charactersIgnoringModifiers: "i",
            isARepeat: false,
            keyCode: 34
        )

        timeline.keyDown(with: keyI!)

        // Verify delegate was called
        XCTAssertEqual(mockDelegate.setInPointCallCount, 1, "I key should trigger set in point")
        XCTAssertEqual(mockDelegate.lastInPointTime, 5.0, "In point should be set to current time (5.0)")
    }

    func testInPointButtonUpdatesUI() {
        let inPointButton = timeline.subviews.compactMap { $0 as? NSButton }.first { $0.title == "I" }
        XCTAssertNotNil(inPointButton, "In Point button should be found")

        // Initially, in point button should be in normal state
        XCTAssertEqual(inPointButton!.identifier?.rawValue, "inPointButton", "Button should have correct identifier")

        // Click to set in point
        timeline.currentTime = 5.0
        inPointButton?.performClick()

        // Verify button appearance changes (assuming visual feedback)
        // This test would be enhanced with actual visual state checking
        XCTAssertEqual(mockDelegate.setInPointCallCount, 1, "Set in point action should have been triggered")
    }
}

// MARK: - Mock Timeline Delegate

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