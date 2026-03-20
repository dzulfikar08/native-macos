import XCTest
@testable import OpenScreen
import AppKit

@MainActor
final class ShuttleWheelControlTests: XCTestCase {

    var shuttleWheel: ShuttleWheelControl!
    var testFrame: CGRect = CGRect(x: 0, y: 0, width: 200, height: 200)

    override func setUp() {
        super.setUp()
        shuttleWheel = ShuttleWheelControl(frame: testFrame)
    }

    override func tearDown() {
        shuttleWheel = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertEqual(shuttleWheel.position, 0.0)
        XCTAssertEqual(shuttleWheel.speed, 0.0)
        XCTAssertEqual(shuttleWheel.state, .idle)
    }

    // MARK: - Position Tests

    func testPositionInRange() {
        // Test position bounds
        shuttleWheel.position = -60.0 // Should be clamped to -50
        XCTAssertEqual(shuttleWheel.position, -50.0)

        shuttleWheel.position = 60.0 // Should be clamped to 50
        XCTAssertEqual(shuttleWheel.position, 50.0)

        shuttleWheel.position = 30.0 // Should be allowed
        XCTAssertEqual(shuttleWheel.position, 30.0)
    }

    func testSpeedRange() {
        // Test speed bounds
        shuttleWheel.speed = -5.0 // Should be clamped to -4.0
        XCTAssertEqual(shuttleWheel.speed, -4.0)

        shuttleWheel.speed = 5.0 // Should be clamped to 4.0
        XCTAssertEqual(shuttleWheel.speed, 4.0)

        shuttleWheel.speed = 2.5 // Should be allowed
        XCTAssertEqual(shuttleWheel.speed, 2.5)
    }

    // MARK: - Drag Interaction Tests

    func testStartDrag() {
        let startPoint = CGPoint(x: 100, y: 100)
        if let event = NSEvent.mouseEvent(with: .leftMouseDown, location: startPoint, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 0) {
            shuttleWheel.handleMouseDown(with: event)
        }

        XCTAssertEqual(shuttleWheel.state, .dragging)
        XCTAssertEqual(shuttleWheel.position, 0.0) // Center position
    }

    func testDragRightIncreasesPosition() {
        // Start drag from center
        let startPoint = CGPoint(x: 100, y: 100)
        if let event = NSEvent.mouseEvent(with: .leftMouseDown, location: startPoint, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 0) {
            shuttleWheel.handleMouseDown(with: event)
        }

        // Drag right
        let dragPoint = CGPoint(x: 150, y: 100) // 50 points right
        if let event = NSEvent.mouseEvent(with: .leftMouseDragged, location: dragPoint, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 0) {
            shuttleWheel.handleMouseDragged(with: event)
        }

        // Should be at position 25 (half of max 50, scaled from 50 pixel drag)
        XCTAssertEqual(shuttleWheel.position, 25.0)
        XCTAssertEqual(shuttleWheel.speed, 2.0) // Positive speed for right drag
    }

    func testDragLeftDecreasesPosition() {
        // Start drag from center
        let startPoint = CGPoint(x: 100, y: 100)
        if let event = NSEvent.mouseEvent(with: .leftMouseDown, location: startPoint, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 0) {
            shuttleWheel.handleMouseDown(with: event)
        }

        // Drag left
        let dragPoint = CGPoint(x: 50, y: 100) // 50 points left
        if let event = NSEvent.mouseEvent(with: .leftMouseDragged, location: dragPoint, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 0) {
            shuttleWheel.handleMouseDragged(with: event)
        }

        // Should be at position -25 (half of max -50, scaled from 50 pixel drag)
        XCTAssertEqual(shuttleWheel.position, -25.0)
        XCTAssertEqual(shuttleWheel.speed, -2.0) // Negative speed for left drag
    }

    func testDragBounds() {
        // Start drag from center
        let startPoint = CGPoint(x: 100, y: 100)
        if let event = NSEvent.mouseEvent(with: .leftMouseDown, location: startPoint, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 0) {
            shuttleWheel.handleMouseDown(with: event)
        }

        // Drag way past right bound
        let dragPoint = CGPoint(x: 200, y: 100) // 100 points right from center
        if let event = NSEvent.mouseEvent(with: .leftMouseDragged, location: dragPoint, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 0) {
            shuttleWheel.handleMouseDragged(with: event)
        }

        // Should be clamped to max position
        XCTAssertEqual(shuttleWheel.position, 50.0)
        XCTAssertEqual(shuttleWheel.speed, 4.0) // Max speed
    }

    func testEndDrag() {
        // Start drag
        let startPoint = CGPoint(x: 100, y: 100)
        if let event = NSEvent.mouseEvent(with: .leftMouseDown, location: startPoint, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 0) {
            shuttleWheel.handleMouseDown(with: event)
        }

        // Drag to some position
        let dragPoint = CGPoint(x: 150, y: 100)
        if let event = NSEvent.mouseEvent(with: .leftMouseDragged, location: dragPoint, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 0) {
            shuttleWheel.handleMouseDragged(with: event)
        }

        XCTAssertEqual(shuttleWheel.state, .dragging)

        // End drag
        if let event = NSEvent.mouseEvent(with: .leftMouseUp, location: dragPoint, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 0) {
            shuttleWheel.handleMouseUp(with: event)
        }

        XCTAssertEqual(shuttleWheel.state, .springing)
    }

    // MARK: - Spring Animation Tests

    func testSpringBackToCenter() {
        // Set position away from center
        shuttleWheel.position = 30.0
        shuttleWheel.state = .springing

        // Advance time to let spring animate
        shuttleWheel.advanceAnimationTime(0.1) // 100ms

        // Position should move towards center
        XCTAssertNotEqual(shuttleWheel.position, 30.0)
        XCTAssertLessThan(abs(shuttleWheel.position), 30.0)
    }

    func testSpringCompletes() {
        // Start spring animation
        shuttleWheel.position = 25.0
        shuttleWheel.state = .springing

        // Let spring complete (this might need several time advances)
        for _ in 0..<100 {
            shuttleWheel.advanceAnimationTime(0.016) // ~60fps
        }

        XCTAssertEqual(shuttleWheel.state, .idle)
        XCTAssertEqual(shuttleWheel.position, 0.0, accuracy: 0.1) // Should be very close to center
        XCTAssertEqual(shuttleWheel.speed, 0.0)
    }

    // MARK: - Speed Calculation Tests

    func testSpeedProportionalToDragDistance() {
        // Test speed calculation based on drag distance
        // Drag half the max distance should give half the max speed
        shuttleWheel.position = 25.0 // Half of max 50
        XCTAssertEqual(shuttleWheel.speed, 2.0) // Half of max 4.0
    }

    func testZeroSpeedAtCenter() {
        shuttleWheel.position = 0.0
        XCTAssertEqual(shuttleWheel.speed, 0.0)
    }

    // MARK: - Visual State Tests

    func testNeedsDisplayOnStateChange() {
        // Initially false
        XCTAssertFalse(shuttleWheel.needsDisplay)

        // Change position
        shuttleWheel.position = 10.0
        XCTAssertTrue(shuttleWheel.needsDisplay)

        // Reset needsDisplay and change state
        shuttleWheel.needsDisplay = false
        shuttleWheel.state = .dragging
        XCTAssertTrue(shuttleWheel.needsDisplay)
    }

    // MARK: - Edge Cases

    func testNoDragWithoutMouseDown() {
        // Try to drag without mouse down
        let dragPoint = CGPoint(x: 150, y: 100)
        if let event = NSEvent.mouseEvent(with: .leftMouseDragged, location: dragPoint, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 0) {
            shuttleWheel.handleMouseDragged(with: event)
        }

        // Should remain in idle state
        XCTAssertEqual(shuttleWheel.state, .idle)
        XCTAssertEqual(shuttleWheel.position, 0.0)
    }

    func testClickWithoutDrag() {
        // Click at center without dragging
        let centerPoint = CGPoint(x: 100, y: 100)
        shuttleWheel.handleMouseDown(with: NSEvent.mouseEvent(with: .leftMouseDown, location: centerPoint, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 0))
        if let event = NSEvent.mouseEvent(with: .leftMouseUp, location: centerPoint, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 0) {
            shuttleWheel.handleMouseUp(with: event)
        }

        // Should return to idle state
        XCTAssertEqual(shuttleWheel.state, .idle)
        XCTAssertEqual(shuttleWheel.position, 0.0)
    }
}