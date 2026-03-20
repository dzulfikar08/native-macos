import XCTest
import AppKit
@testable import OpenScreen

@MainActor
final class TimelineViewInteractionTests: XCTestCase {
    var timelineView: TimelineView!

    override func setUp() async throws {
        try await super.setUp()
        timelineView = TimelineView(frame: NSRect(x: 0, y: 0, width: 800, height: 200))
    }

    override func tearDown() async throws {
        timelineView = nil
        try await super.tearDown()
    }

    // MARK: - Mouse Down Tests

    func testMouseDownOnPlayhead() {
        // Given: A timeline with playhead at center
        let initialTime = 5.0
        timelineView.currentTime = initialTime
        let playheadX = timelineView.timeToXPosition(initialTime)

        // When: Mouse is pressed on playhead
        let mouseEvent = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: NSPoint(x: playheadX, y: 100),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        )!

        timelineView.mouseDown(with: mouseEvent)

        // Then: Playhead should be in dragging state
        XCTAssertTrue(timelineView.isDraggingPlayhead, "Playhead should be in dragging state")
    }

    func testMouseDownOutsidePlayhead() {
        // Given: A timeline with playhead at center
        timelineView.currentTime = 5.0

        // When: Mouse is pressed away from playhead
        let mouseEvent = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: NSPoint(x: 50, y: 100),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        )!

        timelineView.mouseDown(with: mouseEvent)

        // Then: Playhead should not be in dragging state
        XCTAssertFalse(timelineView.isDraggingPlayhead, "Playhead should not be dragging when clicked elsewhere")
    }

    // MARK: - Mouse Dragged Tests

    func testMouseDraggedUpdatesPlayheadPosition() {
        // Given: Playhead is being dragged
        let initialTime = 5.0
        timelineView.currentTime = initialTime
        let playheadX = timelineView.timeToXPosition(initialTime)

        let mouseDownEvent = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: NSPoint(x: playheadX, y: 100),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        )!

        timelineView.mouseDown(with: mouseDownEvent)
        XCTAssertTrue(timelineView.isDraggingPlayhead)

        // When: Mouse is dragged to new position
        let newX: CGFloat = 300
        let dragEvent = NSEvent.mouseEvent(
            with: .leftMouseDragged,
            location: NSPoint(x: newX, y: 100),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 1,
            clickCount: 0,
            pressure: 1.0
        )!

        timelineView.mouseDragged(with: dragEvent)

        // Then: Current time should be updated to match new position
        let expectedTime = timelineView.xPositionToTime(newX)
        XCTAssertEqual(timelineView.currentTime, expectedTime, accuracy: 0.01, "Current time should update during drag")
    }

    func testMouseDraggedRespectsContentOffset() {
        // Given: Timeline with content offset
        timelineView.contentOffset = CGPoint(x: 100, y: 0)
        timelineView.currentTime = 2.0

        let playheadX = timelineView.timeToXPosition(2.0)
        let mouseDownEvent = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: NSPoint(x: playheadX, y: 100),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        )!

        timelineView.mouseDown(with: mouseDownEvent)

        // When: Dragged to a specific x position
        let targetX: CGFloat = 400
        let dragEvent = NSEvent.mouseEvent(
            with: .leftMouseDragged,
            location: NSPoint(x: targetX, y: 100),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 1,
            clickCount: 0,
            pressure: 1.0
        )!

        timelineView.mouseDragged(with: dragEvent)

        // Then: Time should account for content offset
        let expectedTime = timelineView.xPositionToTime(targetX)
        XCTAssertEqual(timelineView.currentTime, expectedTime, accuracy: 0.01)
    }

    // MARK: - Mouse Up Tests

    func testMouseUpEndsDragging() {
        // Given: Playhead is being dragged
        timelineView.currentTime = 5.0
        let playheadX = timelineView.timeToXPosition(5.0)

        let mouseDownEvent = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: NSPoint(x: playheadX, y: 100),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        )!

        timelineView.mouseDown(with: mouseDownEvent)
        XCTAssertTrue(timelineView.isDraggingPlayhead)

        // When: Mouse is released
        let mouseUpEvent = NSEvent.mouseEvent(
            with: .leftMouseUp,
            location: NSPoint(x: playheadX, y: 100),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 2,
            clickCount: 0,
            pressure: 0.0
        )!

        timelineView.mouseUp(with: mouseUpEvent)

        // Then: Playhead should no longer be in dragging state
        XCTAssertFalse(timelineView.isDraggingPlayhead, "Playhead dragging should end on mouse up")
    }

    func testMouseUpWithoutPriorMouseDown() {
        // Given: No mouse down has occurred

        // When: Mouse up occurs directly
        let mouseUpEvent = NSEvent.mouseEvent(
            with: .leftMouseUp,
            location: NSPoint(x: 100, y: 100),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 0,
            pressure: 0.0
        )!

        timelineView.mouseUp(with: mouseUpEvent)

        // Then: Should not crash and dragging should remain false
        XCTAssertFalse(timelineView.isDraggingPlayhead)
    }

    // MARK: - Playhead Hit Detection Tests

    func testPlayheadHitDetectionTolerance() {
        // Given: Playhead at a position
        let time = 5.0
        timelineView.currentTime = time
        let playheadX = timelineView.timeToXPosition(time)

        // When: Clicking within tolerance of playhead
        let tolerance: CGFloat = 5.0 // Pixels
        let clickOffset = tolerance - 1.0 // Just within tolerance

        let mouseEvent = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: NSPoint(x: playheadX + clickOffset, y: 100),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        )!

        timelineView.mouseDown(with: mouseEvent)

        // Then: Should detect playhead hit
        XCTAssertTrue(timelineView.isDraggingPlayhead, "Should detect click within tolerance")
    }

    func testPlayheadHitDetectionOutsideTolerance() {
        // Given: Playhead at a position
        let time = 5.0
        timelineView.currentTime = time
        let playheadX = timelineView.timeToXPosition(time)

        // When: Clicking outside tolerance
        let tolerance: CGFloat = 5.0
        let clickOffset = tolerance + 1.0 // Just outside tolerance

        let mouseEvent = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: NSPoint(x: playheadX + clickOffset, y: 100),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        )!

        timelineView.mouseDown(with: mouseEvent)

        // Then: Should not detect playhead hit
        XCTAssertFalse(timelineView.isDraggingPlayhead, "Should not detect click outside tolerance")
    }
}
