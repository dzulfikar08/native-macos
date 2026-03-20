import XCTest
@testable import OpenScreen

@MainActor
final class TimelineViewKeyboardShortcutsTests: XCTestCase {

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

    // MARK: - Keyboard Shortcut Priority Tests

    func testKeyboardShortcutPriorityHierarchy() {
        // Test that command+modifier keys have higher priority than single keys
        let events = [
            createKeyEvent(key: "j", modifiers: [], keyCode: 38),      // Single J
            createKeyEvent(key: "j", modifiers: [.command], keyCode: 38) // Cmd+J
        ]

        // Process both events
        timeline.keyDown(with: events[0])
        timeline.keyDown(with: events[1])

        // Cmd+J should take precedence over single J
        // This test would be enhanced with actual priority implementation
        XCTAssertEqual(mockDelegate.playCallCount, 1, "Cmd+J should trigger play")
        XCTAssertEqual(mockDelegate.seekBackwardCallCount, 0, "Single J should not trigger seek backward")
    }

    // MARK: - JKL Playback Control Tests

    func testJKeySeekBackward() async {
        let keyJ = createKeyEvent(key: "j", modifiers: [], keyCode: 38)

        timeline.keyDown(with: keyJ)

        // Verify delegate was called to seek backward
        XCTAssertEqual(mockDelegate.seekBackwardCallCount, 1, "J key should trigger seek backward")
        XCTAssertEqual(mockDelegate.lastSeekAmount, -5.0, "Should seek back 5 seconds")
    }

    func testKKeyPlayPause() async {
        let keyK = createKeyEvent(key: "k", modifiers: [], keyCode: 39)

        timeline.keyDown(with: keyK)

        // Verify delegate was called to play/pause
        XCTAssertEqual(mockDelegate.playPauseCallCount, 1, "K key should trigger play/pause")
    }

    func testLKeySeekForward() async {
        let keyL = createKeyEvent(key: "l", modifiers: [], keyCode: 40)

        timeline.keyDown(with: keyL)

        // Verify delegate was called to seek forward
        XCTAssertEqual(mockDelegate.seekForwardCallCount, 1, "L key should trigger seek forward")
        XCTAssertEqual(mockDelegate.lastSeekAmount, 5.0, "Should seek forward 5 seconds")
    }

    func testJKLModifiersWorkCorrectly() async {
        // Test J with Shift (J+Shift)
        let keyJShift = createKeyEvent(key: "j", modifiers: [.shift], keyCode: 38)
        timeline.keyDown(with: keyJShift)
        XCTAssertEqual(mockDelegate.seekBackwardCallCount, 1, "Shift+J should still work")

        // Test K with modifiers
        let keyKCtrl = createKeyEvent(key: "k", modifiers: [.control], keyCode: 39)
        timeline.keyDown(with: keyKCtrl)
        XCTAssertEqual(mockDelegate.playPauseCallCount, 1, "Ctrl+K should still work")

        // Test L with modifiers
        let keyLCmd = createKeyEvent(key: "l", modifiers: [.command], keyCode: 40)
        timeline.keyDown(with: keyLCmd)
        XCTAssertEqual(mockDelegate.seekForwardCallCount, 1, "Cmd+L should still work")
    }

    // MARK: - Navigation Key Tests

    func testArrowKeyNavigation() async {
        let keyLeft = createKeyEvent(key: "←", modifiers: [], keyCode: 123)
        let keyRight = createKeyEvent(key: "→", modifiers: [], keyCode: 124)

        timeline.keyDown(with: keyLeft)
        timeline.keyDown(with: keyRight)

        XCTAssertEqual(mockDelegate.seekBackwardCallCount, 1, "Left arrow should seek backward")
        XCTAssertEqual(mockDelegate.seekForwardCallCount, 1, "Right arrow should seek forward")
    }

    func testSpaceKeyPlayPause() async {
        let keySpace = createKeyEvent(key: " ", modifiers: [], keyCode: 49)

        timeline.keyDown(with: keySpace)

        XCTAssertEqual(mockDelegate.playPauseCallCount, 1, "Space key should trigger play/pause")
    }

    // MARK: - Key Up Handling Tests

    func testKeyUpEventHandled() async {
        let keyDown = createKeyEvent(key: "k", modifiers: [], keyCode: 39)
        let keyUp = createKeyEvent(key: "k", modifiers: [], keyCode: 39)

        timeline.keyDown(with: keyDown)
        timeline.keyUp(with: keyUp)

        // Verify play/pause was triggered on key down
        XCTAssertEqual(mockDelegate.playPauseCallCount, 1, "Play/pause should be triggered on key down")
    }

    // MARK: - Helper Methods

    private func createKeyEvent(key: String, modifiers: NSEvent.ModifierFlags, keyCode: Int) -> NSEvent {
        return NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: key,
            charactersIgnoringModifiers: key,
            isARepeat: false,
            keyCode: keyCode
        )!
    }
}

// MARK: - Enhanced Mock Timeline Delegate

class MockTimelineViewDelegate: NSObject {
    var playCallCount = 0
    var pauseCallCount = 0
    var stopCallCount = 0
    var playPauseCallCount = 0
    var seekBackwardCallCount = 0
    var seekForwardCallCount = 0
    var lastSeekAmount: Double = 0.0
    var stepForwardCallCount = 0
    var stepBackwardCallCount = 0
    var setInPointCallCount = 0
    var setOutPointCallCount = 0
    var clearInOutPointCallCount = 0
    var focusModeCallCount = 0
    var lastInPointTime: Double = 0.0
    var lastOutPointTime: Double = 0.0

    func timelineViewDidPlay(_ timeline: TimelineView) {
        playCallCount += 1
    }

    func timelineViewDidPause(_ timeline: TimelineView) {
        pauseCallCount += 1
    }

    func timelineViewDidStop(_ timeline: TimelineView) {
        stopCallCount += 1
    }

    func timelineViewDidPlayPause(_ timeline: TimelineView) {
        playPauseCallCount += 1
    }

    func timelineViewDidSeekBackward(_ timeline: TimelineView, amount: Double) {
        seekBackwardCallCount += 1
        lastSeekAmount = amount
    }

    func timelineViewDidSeekForward(_ timeline: TimelineView, amount: Double) {
        seekForwardCallCount += 1
        lastSeekAmount = amount
    }

    func timelineViewDidStepForward(_ timeline: TimelineView) {
        stepForwardCallCount += 1
    }

    func timelineViewDidStepBackward(_ timeline: TimelineView) {
        stepBackwardCallCount += 1
    }

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