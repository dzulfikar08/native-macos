import XCTest
@testable import OpenScreen

@MainActor
final class TimelineViewOutPointTests: XCTestCase {

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

    // MARK: - Out Point Button Tests

    func testOutPointButtonExists() {
        let buttons = timeline.subviews.compactMap { $0 as? NSButton }
        let outPointButton = buttons.first { $0.title == "O" || $0.toolTip?.contains("Set Out Point") ?? false }
        XCTAssertNotNil(outPointButton, "Out Point button should exist")
    }

    func testOutPointButtonAction() {
        let outPointButton = timeline.subviews.compactMap { $0 as? NSButton }.first { $0.title == "O" }
        XCTAssertNotNil(outPointButton, "Out Point button should be found")

        // Set current time to 10 seconds
        timeline.currentTime = 10.0

        // Simulate button click
        outPointButton?.performClick()

        // Verify delegate was called to set out point
        XCTAssertEqual(mockDelegate.setOutPointCallCount, 1, "Delegate should have been called to set out point")
        XCTAssertEqual(mockDelegate.lastOutPointTime, 10.0, "Out point should be set to current time (10.0)")
    }

    func testOutPointKeyboardShortcut() async {
        // Set current time
        timeline.currentTime = 10.0

        // Test O key for set out point
        let keyO = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "o",
            charactersIgnoringModifiers: "o",
            isARepeat: false,
            keyCode: 35
        )

        timeline.keyDown(with: keyO!)

        // Verify delegate was called
        XCTAssertEqual(mockDelegate.setOutPointCallCount, 1, "O key should trigger set out point")
        XCTAssertEqual(mockDelegate.lastOutPointTime, 10.0, "Out point should be set to current time (10.0)")
    }

    func testOutPointButtonUpdatesUI() {
        let outPointButton = timeline.subviews.compactMap { $0 as? NSButton }.first { $0.title == "O" }
        XCTAssertNotNil(outPointButton, "Out Point button should be found")

        // Initially, out point button should be in normal state
        XCTAssertEqual(outPointButton!.identifier?.rawValue, "outPointButton", "Button should have correct identifier")

        // Click to set out point
        timeline.currentTime = 10.0
        outPointButton?.performClick()

        // Verify button appearance changes
        XCTAssertEqual(mockDelegate.setOutPointCallCount, 1, "Set out point action should have been triggered")
    }
}

// MARK: - Mock Timeline Delegate (same as InPoint tests)

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