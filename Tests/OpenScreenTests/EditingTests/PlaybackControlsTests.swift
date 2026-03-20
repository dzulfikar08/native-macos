import XCTest
@testable import OpenScreen

@MainActor
final class PlaybackControlsTests: XCTestCase {

    var controls: PlaybackControls!
    var mockDelegate: MockPlaybackControlsDelegate!

    override func setUp() async throws {
        controls = PlaybackControls(frame: NSRect(x: 0, y: 0, width: 400, height: 50))
        mockDelegate = MockPlaybackControlsDelegate()
        controls.delegate = mockDelegate
    }

    override func tearDown() async throws {
        controls = nil
        mockDelegate = nil
    }

    // MARK: - Frame Step Tests

    func testFrameStepButtonsExist() {
        // Verify that frame step buttons are added to the view
        let buttons = controls.subviews.compactMap { $0 as? NSButton }

        // Check that previous frame button exists
        let prevFrameButton = buttons.first { $0.title == "Previous Frame" || $0.toolTip?.contains("Previous Frame") ?? false }
        XCTAssertNotNil(prevFrameButton, "Previous Frame button should exist")

        // Check that next frame button exists
        let nextFrameButton = buttons.first { $0.title == "Next Frame" || $0.toolTip?.contains("Next Frame") ?? false }
        XCTAssertNotNil(nextFrameButton, "Next Frame button should exist")
    }

    func testPreviousFrameButtonAction() async {
        // Test that previous frame button calls stepBackward through delegate
        controls.updateMaxPosition(10.0)
        controls.updatePosition(to: 5.0)

        let prevFrameButton = controls.subviews.compactMap { $0 as? NSButton }.first { $0.action == #selector(controls.previousFrame) }
        XCTAssertNotNil(prevFrameButton, "Previous Frame button should be found")

        // Simulate button click
        prevFrameButton?.performClick()

        // Verify delegate was called to step backward
        XCTAssertEqual(mockDelegate.stepBackwardCallCount, 1, "Delegate should have been called once")
        XCTAssertEqual(mockDelegate.lastSeekAmount, -0.033, "Should seek back by one frame (1/30 seconds)")
    }

    func testNextFrameButtonAction() async {
        // Test that next frame button calls stepForward through delegate
        controls.updateMaxPosition(10.0)
        controls.updatePosition(to: 5.0)

        let nextFrameButton = controls.subviews.compactMap { $0 as? NSButton }.first { $0.action == #selector(controls.nextFrame) }
        XCTAssertNotNil(nextFrameButton, "Next Frame button should be found")

        // Simulate button click
        nextFrameButton?.performClick()

        // Verify delegate was called to step forward
        XCTAssertEqual(mockDelegate.stepForwardCallCount, 1, "Delegate should have been called once")
        XCTAssertEqual(mockDelegate.lastSeekAmount, 0.033, "Should seek forward by one frame (1/30 seconds)")
    }

    func testFrameStepButtonsPositionedBetweenStopAndPlay() {
        let buttons = controls.subviews.compactMap { $0 as? NSButton }
        let buttonFrames = buttons.map { $0.frame.origin.x }

        let stopButton = buttons.first { $0.title == "Stop" }
        let playButton = buttons.first { $0.title.contains("Play") || $0.title.contains("Pause") }
        let prevFrameButton = buttons.first { $0.action == #selector(controls.previousFrame) }
        let nextFrameButton = buttons.first { $0.action == #selector(controls.nextFrame) }

        XCTAssertNotNil(stopButton, "Stop button should exist")
        XCTAssertNotNil(playButton, "Play/Pause button should exist")
        XCTAssertNotNil(prevFrameButton, "Previous Frame button should exist")
        XCTAssertNotNil(nextFrameButton, "Next Frame button should exist")

        // Verify ordering: stop -> prevFrame -> nextFrame -> play/pause
        let stopIndex = buttonFrames.firstIndex(where: { $0 == stopButton!.frame.origin.x })!
        let prevFrameIndex = buttonFrames.firstIndex(where: { $0 == prevFrameButton!.frame.origin.x })!
        let nextFrameIndex = buttonFrames.firstIndex(where: { $0 == nextFrameButton!.frame.origin.x })!
        let playIndex = buttonFrames.firstIndex(where: { $0 == playButton!.frame.origin.x })!

        XCTAssertTrue(stopIndex < prevFrameIndex, "Stop button should come before Previous Frame button")
        XCTAssertTrue(prevFrameIndex < nextFrameIndex, "Previous Frame button should come before Next Frame button")
        XCTAssertTrue(nextFrameIndex < playIndex, "Next Frame button should come before Play button")
    }

    func testFrameStepKeyboardShortcuts() async {
        // Test Cmd+Up for previous frame
        let keyUp = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "↑",
            charactersIgnoringModifiers: "↑",
            isARepeat: false,
            keyCode: 126
        )

        controls.keyDown(with: keyUp!)

        // Verify delegate was called
        XCTAssertEqual(mockDelegate.stepBackwardCallCount, 1, "Cmd+Up should trigger previous frame")

        // Test Cmd+Down for next frame
        let keyDown = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "↓",
            charactersIgnoringModifiers: "↓",
            isARepeat: false,
            keyCode: 125
        )

        controls.keyDown(with: keyDown!)

        // Verify delegate was called
        XCTAssertEqual(mockDelegate.stepForwardCallCount, 1, "Cmd+Down should trigger next frame")
    }
}

// MARK: - Mock Delegate

class MockPlaybackControlsDelegate: PlaybackControlsDelegate {
    var stepForwardCallCount = 0
    var stepBackwardCallCount = 0
    var lastSeekAmount: Double = 0.0

    func playbackControlsDidPlay(_ controls: PlaybackControls) {
        // Not implemented for these tests
    }

    func playbackControlsDidPause(_ controls: PlaybackControls) {
        // Not implemented for these tests
    }

    func playbackControlsDidStop(_ controls: PlaybackControls) {
        // Not implemented for these tests
    }

    func playbackControls(_ controls: PlaybackControls, didSeekBy amount: Double) {
        lastSeekAmount = amount
        if amount > 0 {
            stepForwardCallCount += 1
        } else {
            stepBackwardCallCount += 1
        }
    }

    func playbackControls(_ controls: PlaybackControls, didUpdatePosition position: Double) {
        // Not implemented for these tests
    }
}