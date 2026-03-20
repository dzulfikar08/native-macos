import XCTest
@testable import OpenScreen
import AppKit

@MainActor
final class JKLControllerTests: XCTestCase {

    var editorState: EditorState!
    var jklController: JKLController!

    override func setUp() {
        super.setUp()
        editorState = EditorState.createTestState()
        jklController = JKLController(editorState: editorState)
    }

    override func tearDown() {
        editorState = nil
        jklController = nil
        super.tearDown()
    }

    // MARK: - JKLState Tests

    func testInitialStateIsPaused() {
        XCTAssertEqual(jklController.state, .paused)
    }

    func testStateTransitions() {
        // Test paused -> playing
        jklController.handleKeyDown(.j)
        XCTAssertEqual(jklController.state, .playing)
        XCTAssertEqual(editorState.isPlaying, true)
        XCTAssertEqual(editorState.playbackRate, 1.0)

        // Test playing -> reverse
        jklController.handleKeyDown(.k)
        XCTAssertEqual(jklController.state, .reverse)
        XCTAssertEqual(editorState.isPlaying, true)
        XCTAssertEqual(editorState.playbackRate, -1.0)

        // Test reverse -> paused
        jklController.handleKeyDown(.l)
        XCTAssertEqual(jklController.state, .paused)
        XCTAssertEqual(editorState.isPlaying, false)
        XCTAssertEqual(editorState.playbackRate, 1.0)
    }

    func testSameKeyTogglesState() {
        // Initial state: paused
        XCTAssertEqual(jklController.state, .paused)

        // Press J -> playing
        jklController.handleKeyDown(.j)
        XCTAssertEqual(jklController.state, .playing)

        // Press J again -> paused
        jklController.handleKeyUp(.j)
        jklController.handleKeyDown(.j)
        XCTAssertEqual(jklController.state, .paused)
    }

    // MARK: - Acceleration Tests

    func testInitialPressHas1xSpeed() {
        jklController.handleKeyDown(.j)
        XCTAssertEqual(editorState.playbackRate, 1.0)
    }

    func testAccelerationTo2xAfter0_5Seconds() {
        // Press and hold J
        jklController.handleKeyDown(.j)
        XCTAssertEqual(editorState.playbackRate, 1.0)

        // Simulate 0.5 second hold
        jklController.simulateTimePassed(0.5)
        XCTAssertEqual(editorState.playbackRate, 2.0)
    }

    func testAccelerationTo4xAfter1SecondTotalHold() {
        // Press and hold J
        jklController.handleKeyDown(.j)
        XCTAssertEqual(editorState.playbackRate, 1.0)

        // Simulate 0.5 second hold (should accelerate to 2x)
        jklController.simulateTimePassed(0.5)
        XCTAssertEqual(editorState.playbackRate, 2.0)

        // Simulate another 0.5 second hold (should accelerate to 4x)
        jklController.simulateTimePassed(0.5)
        XCTAssertEqual(editorState.playbackRate, 4.0)
    }

    func testResetTo1xOnKeyUp() {
        // Press and accelerate to 4x
        jklController.handleKeyDown(.j)
        jklController.simulateTimePassed(1.0)
        XCTAssertEqual(editorState.playbackRate, 4.0)

        // Release key
        jklController.handleKeyUp(.j)

        // Press again - should start back at 1x
        jklController.handleKeyDown(.j)
        XCTAssertEqual(editorState.playbackRate, 1.0)
    }

    func testDifferentKeysHaveIndependentAcceleration() {
        // Press and hold J to 4x
        jklController.handleKeyDown(.j)
        jklController.simulateTimePassed(1.0)
        XCTAssertEqual(editorState.playbackRate, 4.0)

        // Press K - should start at 1x for K
        jklController.handleKeyDown(.k)
        XCTAssertEqual(editorState.playbackRate, -1.0)
    }

    // MARK: - Key Mapping Tests

    func testJKeyMapsToPlayingState() {
        jklController.handleKeyDown(.j)
        XCTAssertEqual(jklController.state, .playing)
        XCTAssertEqual(editorState.isPlaying, true)
        XCTAssertEqual(editorState.playbackRate, 1.0)
    }

    func testKKeyMapsToReverseState() {
        jklController.handleKeyDown(.j) // First need to be playing
        jklController.handleKeyDown(.k)
        XCTAssertEqual(jklController.state, .reverse)
        XCTAssertEqual(editorState.isPlaying, true)
        XCTAssertEqual(editorState.playbackRate, -1.0)
    }

    func testLKeyMapsToPausedState() {
        jklController.handleKeyDown(.j) // Start playing
        jklController.handleKeyDown(.l) // Stop
        XCTAssertEqual(jklController.state, .paused)
        XCTAssertEqual(editorState.isPlaying, false)
    }

    // MARK: - Edge Cases

    func testMultipleRapidKeyPresses() {
        // Rapid sequence: J -> K -> L -> J
        jklController.handleKeyDown(.j)
        XCTAssertEqual(editorState.isPlaying, true)

        jklController.handleKeyDown(.k)
        XCTAssertEqual(editorState.playbackRate, -1.0)

        jklController.handleKeyDown(.l)
        XCTAssertEqual(editorState.isPlaying, false)

        jklController.handleKeyDown(.j)
        XCTAssertEqual(editorState.isPlaying, true)
    }

    func testUnknownKeysAreIgnored() {
        // Unknown key should not change state
        jklController.handleKeyDown(.unknown)
        XCTAssertEqual(jklController.state, .paused)
        XCTAssertEqual(editorState.isPlaying, false)
    }
}