import XCTest
import AppKit
@testable import OpenScreen

@MainActor
final class TimelineViewLoopCreationTests: XCTestCase {

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

        // Set up zoom for testing
        timelineView.zoom(to: 50.0)
    }

    override func tearDown() {
        timelineView = nil
        mockDelegate = nil
        testEditorState = nil
        super.tearDown()
    }

    func testLoopCreationNotActiveInitially() {
        XCTAssertFalse(timelineView.isCreatingLoop, "Loop creation should not be active initially")
        XCTAssertEqual(timelineView.loopDragStartX, 0.0, "Loop drag start should be zero")
        XCTAssertEqual(timelineView.loopDragCurrentX, 0.0, "Loop drag current should be zero")
    }

    func testStartLoopCreationOnDrag() {
        // Create a mouse event without Cmd key (for loop creation)
        let startLocation = NSPoint(x: 100, y: 100)
        let mouseEvent = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: startLocation,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        )

        // Make sure we're not clicking on playhead
        timelineView.currentTime = 5.0 // Position playhead at time 5.0
        timelineView.zoom(to: 50.0) // Scale so playhead is at x=250

        // Perform mouse down away from playhead (x=100, playhead at x=250)
        timelineView.mouseDown(with: mouseEvent!)

        XCTAssertTrue(timelineView.isCreatingLoop, "Loop creation should be active after drag")
        XCTAssertEqual(timelineView.loopDragStartX, 100.0, "Loop drag start should match click position")
        XCTAssertEqual(timelineView.loopDragCurrentX, 100.0, "Loop drag current should match click position")
    }

    func testLoopCreationNotActivatedOnPlayhead() {
        // Create a mouse event on playhead without Cmd key
        let playheadX = 100.0 // Simulate playhead position
        let location = NSPoint(x: playheadX, y: 100)
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

        // Perform mouse down on playhead
        timelineView.mouseDown(with: mouseEvent!)

        XCTAssertFalse(timelineView.isCreatingLoop, "Loop creation should not be active when clicking on playhead")
        XCTAssertTrue(timelineView.isDraggingPlayhead, "Normal playhead dragging should be active instead")
    }

    func testLoopCreationWithMouseDrag() {
        // Set up initial state
        let startLocation = NSPoint(x: 100, y: 100)
        let startEvent = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: startLocation,
            modifierFlags: [],
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
            modifierFlags: [],
            timestamp: 0.016,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        )
        timelineView.mouseDragged(with: dragEvent!)

        XCTAssertTrue(timelineView.isCreatingLoop, "Loop creation should continue during drag")
        XCTAssertEqual(timelineView.loopDragCurrentX, 200.0, "Loop drag current should update during drag")
    }

    func testLoopCreationCompletion() {
        // Set up initial state and drag
        let startLocation = NSPoint(x: 100, y: 100)
        let startEvent = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: startLocation,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        )
        timelineView.mouseDown(with: startEvent!)

        let dragLocation = NSPoint(x: 200, y: 100)
        let dragEvent = NSEvent.mouseEvent(
            with: .leftMouseDragged,
            location: dragLocation,
            modifierFlags: [],
            timestamp: 0.016,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        )
        timelineView.mouseDragged(with: dragEvent!)

        // Complete loop creation
        let endEvent = NSEvent.mouseEvent(
            with: .leftMouseUp,
            location: dragLocation,
            modifierFlags: [],
            timestamp: 0.032,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        )
        timelineView.mouseUp(with: endEvent!)

        XCTAssertFalse(timelineView.isCreatingLoop, "Loop creation should end on mouse up")
        XCTAssertEqual(testEditorState.loopRegions.count, 1, "One loop region should be created")

        let createdLoop = testEditorState.loopRegions.first!
        XCTAssertEqual(createdLoop.name, "Loop 1", "Loop should be named 'Loop 1'")
        XCTAssertEqual(createdLoop.timeRange.lowerBound.seconds, 2.0, "Loop start time should be correct") // x=100, scale=50
        XCTAssertEqual(createdLoop.timeRange.upperBound.seconds, 4.0, "Loop end time should be correct") // x=200, scale=50
        XCTAssertFalse(createdLoop.useInOutPoints, "Loop should not use in/out points by default")
    }

    func testLoopCreationMinimumDurationValidation() {
        // Create a very small drag (should be rejected)
        let startLocation = NSPoint(x: 100, y: 100)
        let startEvent = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: startLocation,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        )
        timelineView.mouseDown(with: startEvent!)

        // Drag by only 1 pixel (should be less than minimum duration)
        let dragLocation = NSPoint(x: 101, y: 100)
        let dragEvent = NSEvent.mouseEvent(
            with: .leftMouseDragged,
            location: dragLocation,
            modifierFlags: [],
            timestamp: 0.016,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        )
        timelineView.mouseDragged(with: dragEvent!)

        // Complete loop creation
        let endEvent = NSEvent.mouseEvent(
            with: .leftMouseUp,
            location: dragLocation,
            modifierFlags: [],
            timestamp: 0.032,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        )
        timelineView.mouseUp(with: endEvent!)

        XCTAssertEqual(testEditorState.loopRegions.count, 0, "No loop should be created if duration is too short")
    }

    func testLoopCreationOverlay() {
        // Start loop creation
        let startLocation = NSPoint(x: 100, y: 100)
        let startEvent = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: startLocation,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        )
        timelineView.mouseDown(with: startEvent!)

        XCTAssertNotNil(timelineView.loopCreationOverlay, "Loop creation overlay should be created")
        XCTAssertEqual(timelineView.loopCreationOverlay?.frame.origin.x, 100.0, "Overlay should start at drag position")
        XCTAssertEqual(timelineView.loopCreationOverlay?.frame.width, 0.0, "Overlay width should be zero initially")
    }

    func testLoopCreationOverlayUpdates() {
        // Start loop creation and drag
        let startLocation = NSPoint(x: 100, y: 100)
        let startEvent = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: startLocation,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        )
        timelineView.mouseDown(with: startEvent!)

        let dragLocation = NSPoint(x: 200, y: 100)
        let dragEvent = NSEvent.mouseEvent(
            with: .leftMouseDragged,
            location: dragLocation,
            modifierFlags: [],
            timestamp: 0.016,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        )
        timelineView.mouseDragged(with: dragEvent!)

        XCTAssertEqual(timelineView.loopCreationOverlay?.frame.origin.x, 100.0, "Overlay should start at minimum x")
        XCTAssertEqual(timelineView.loopCreationOverlay?.frame.width, 100.0, "Overlay should span the drag distance")
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