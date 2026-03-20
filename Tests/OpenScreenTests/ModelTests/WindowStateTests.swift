import XCTest
@testable import OpenScreen

final class WindowStateTests: XCTestCase {

    // MARK: - State Transitions Tests

    func testWindowStateTransitions() {
        let state = WindowState.idle

        // Test valid transitions from idle state
        XCTAssertTrue(state.canTransitionTo.contains(.sourceSelector))
        XCTAssertEqual(state.canTransitionTo.count, 1)

        // Test invalid transitions from idle state
        XCTAssertFalse(state.canTransitionTo.contains(.recording))
        XCTAssertFalse(state.canTransitionTo.contains(.editing))
        XCTAssertFalse(state.canTransitionTo.contains(.exporting))
    }

    func testRecordingStateTransitions() {
        let state = WindowState.recording

        // Test valid transitions from recording state
        XCTAssertTrue(state.canTransitionTo.contains(.idle))
        XCTAssertTrue(state.canTransitionTo.contains(.editing))
        XCTAssertEqual(state.canTransitionTo.count, 2)

        // Test invalid transitions from recording state
        XCTAssertFalse(state.canTransitionTo.contains(.sourceSelector))
        XCTAssertFalse(state.canTransitionTo.contains(.exporting))
    }

    func testSourceSelectorStateTransitions() {
        let state = WindowState.sourceSelector

        // Test valid transitions from sourceSelector state
        XCTAssertTrue(state.canTransitionTo.contains(.idle))
        XCTAssertTrue(state.canTransitionTo.contains(.recording))
        XCTAssertTrue(state.canTransitionTo.contains(.editing))
        XCTAssertEqual(state.canTransitionTo.count, 3)

        // Test invalid transitions from sourceSelector state
        XCTAssertFalse(state.canTransitionTo.contains(.sourceSelector))
        XCTAssertFalse(state.canTransitionTo.contains(.exporting))
    }

    func testEditingStateTransitions() {
        let state = WindowState.editing

        // Test valid transitions from editing state
        XCTAssertTrue(state.canTransitionTo.contains(.idle))
        XCTAssertTrue(state.canTransitionTo.contains(.exporting))
        XCTAssertEqual(state.canTransitionTo.count, 2)

        // Test invalid transitions from editing state
        XCTAssertFalse(state.canTransitionTo.contains(.sourceSelector))
        XCTAssertFalse(state.canTransitionTo.contains(.recording))
        XCTAssertFalse(state.canTransitionTo.contains(.editing))
    }

    func testSourceSelectorToEditingTransition() {
        let state = WindowState.sourceSelector

        // Test that .editing is a valid transition from .sourceSelector
        XCTAssertTrue(state.canTransitionTo.contains(.editing), ".editing should be in valid transitions from .sourceSelector")
    }

    func testExportingStateTransitions() {
        let state = WindowState.exporting

        // Test valid transitions from exporting state
        XCTAssertTrue(state.canTransitionTo.contains(.editing))
        XCTAssertEqual(state.canTransitionTo.count, 1)

        // Test invalid transitions from exporting state
        XCTAssertFalse(state.canTransitionTo.contains(.idle))
        XCTAssertFalse(state.canTransitionTo.contains(.sourceSelector))
        XCTAssertFalse(state.canTransitionTo.contains(.recording))
        XCTAssertFalse(state.canTransitionTo.contains(.exporting))
    }

    // MARK: - Equatable Conformance Tests

    func testEquatable() {
        // Test same states are equal
        XCTAssertEqual(WindowState.idle, WindowState.idle)
        XCTAssertEqual(WindowState.recording, WindowState.recording)

        // Test different states are not equal
        XCTAssertNotEqual(WindowState.idle, WindowState.sourceSelector)
        XCTAssertNotEqual(WindowState.recording, WindowState.editing)
        XCTAssertNotEqual(WindowState.editing, WindowState.exporting)
    }
}
