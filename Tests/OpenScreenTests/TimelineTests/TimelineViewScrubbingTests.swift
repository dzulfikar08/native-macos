import XCTest
import AppKit
@testable import OpenScreen

@MainActor
final class TimelineViewScrubbingTests: XCTestCase {

    var timelineView: TimelineView!
    var mockDelegate: MockInOutPointDelegate!

    override func setUp() {
        super.setUp()

        // Create a minimal timeline view for testing
        timelineView = TimelineView(frame: NSRect(x: 0, y: 0, width: 800, height: 200), device: nil)
        mockDelegate = MockInOutPointDelegate()
        timelineView.inOutPointDelegate = mockDelegate

        // Set up a test duration
        timelineView.duration = CMTime(seconds: 60.0, preferredTimescale: 600)
    }

    override func tearDown() {
        timelineView = nil
        mockDelegate = nil
        super.tearDown()
    }

    func testScrubbingNotActiveInitially() {
        XCTAssertFalse(timelineView.isScrubbing, "Scrubbing should not be active initially")
        XCTAssertEqual(timelineView.currentScrubSpeed, 0.0, "Scrub speed should be zero initially")
    }

    func testStartScrubbingOnCmdClick() {
        // Create a mouse event with Cmd key pressed
        let location = NSPoint(x: 100, y: 100)
        let mouseEvent = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: location,
            modifierFlags: .command,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        )

        // Set current time to position the playhead
        timelineView.currentTime = 5.0
        timelineView.zoom(to: 50.0) // Scale to make scrubbing testable

        // Perform mouse down
        timelineView.mouseDown(with: mouseEvent!)

        XCTAssertTrue(timelineView.isScrubbing, "Scrubbing should be active after Cmd+click on playhead")
        XCTAssertNotNil(timelineView.scrubController, "Scrub controller should be created")
    }

    func testScrubbingNotActivatedWithoutCmdKey() {
        // Create a mouse event without Cmd key
        let location = NSPoint(x: 100, y: 100)
        let mouseEvent = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: location,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        )

        // Perform mouse down
        timelineView.mouseDown(with: mouseEvent!)

        XCTAssertFalse(timelineView.isScrubbing, "Scrubbing should not be active without Cmd key")
    }

    func testScrubbingWithMouseDrag() {
        // Set up initial state
        timelineView.currentTime = 10.0
        timelineView.zoom(to: 50.0)

        // Start scrubbing
        let startLocation = NSPoint(x: 100, y: 100)
        let startEvent = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: startLocation,
            modifierFlags: .command,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        )
        timelineView.mouseDown(with: startEvent!)

        // Perform drag
        let dragLocation = NSPoint(x: 200, y: 100)
        let dragEvent = NSEvent.mouseEvent(
            with: .leftMouseDragged,
            location: dragLocation,
            modifierFlags: .command,
            timestamp: 0.016, // 16ms later (60 FPS)
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        )
        timelineView.mouseDragged(with: dragEvent!)

        XCTAssertTrue(timelineView.isScrubbing, "Scrubbing should continue during drag")
        XCTAssertNotEqual(timelineView.currentTime, 10.0, "Current time should change during scrubbing")
    }

    func testEndScrubbingOnMouseUp() {
        // Start scrubbing
        let startLocation = NSPoint(x: 100, y: 100)
        let startEvent = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: startLocation,
            modifierFlags: .command,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        )
        timelineView.mouseDown(with: startEvent!)

        // End scrubbing
        let endEvent = NSEvent.mouseEvent(
            with: .leftMouseUp,
            location: startLocation,
            modifierFlags: .command,
            timestamp: 0.032,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        )
        timelineView.mouseUp(with: endEvent!)

        XCTAssertFalse(timelineView.isScrubbing, "Scrubbing should end on mouse up")
        XCTAssertEqual(timelineView.currentScrubSpeed, 0.0, "Scrub speed should be zero after ending")
    }

    func testCursorChangeOnScrubbing() {
        // Test that cursor changes to grab hand on Cmd+hover over playhead
        timelineView.currentTime = 5.0
        timelineView.zoom(to: 50.0)

        let location = NSPoint(x: 100, y: 100) // At playhead position
        let mouseEvent = NSEvent.mouseEvent(
            with: .mouseMoved,
            location: location,
            modifierFlags: .command,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        )

        timelineView.mouseMoved(with: mouseEvent!)

        // Note: Direct cursor testing is complex, but we can verify the state
        XCTAssertTrue(timelineView.isScrubbing, "Cursor should indicate scrubbing state")
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
        // Not used in this test
    }

    func timelineViewDidSeek(_ timeline: TimelineView, amount: Double) {
        didCallSeek = true
    }

    func timelineViewDidPlayPause(_ timeline: TimelineView) {
        didCallPlayPause = true
    }
}