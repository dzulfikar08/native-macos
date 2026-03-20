import XCTest
@testable import OpenScreen

@MainActor
final class LoopControlTests: XCTestCase {

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

    // MARK: - Loop Control Tests

    func testLoopControlButtonsExist() {
        let buttons = controls.subviews.compactMap { $0 as? NSButton }

        // Check that set loop start button exists
        let setLoopStartButton = buttons.first { $0.title.contains("Loop Start") || $0.toolTip?.contains("Set Loop Start") ?? false }
        XCTAssertNotNil(setLoopStartButton, "Set Loop Start button should exist")

        // Check that set loop end button exists
        let setLoopEndButton = buttons.first { $0.title.contains("Loop End") || $0.toolTip?.contains("Set Loop End") ?? false }
        XCTAssertNotNil(setLoopEndButton, "Set Loop End button should exist")

        // Check that clear loop button exists
        let clearLoopButton = buttons.first { $0.title.contains("Clear Loop") || $0.toolTip?.contains("Clear Loop") ?? false }
        XCTAssertNotNil(clearLoopButton, "Clear Loop button should exist")
    }

    func testSetLoopStartButtonAction() {
        let setLoopStartButton = controls.subviews.compactMap { $0 as? NSButton }.first { $0.action == #selector(controls.setLoopStart) }
        XCTAssertNotNil(setLoopStartButton, "Set Loop Start button should be found")

        // Simulate button click
        setLoopStartButton?.performClick()

        // Verify delegate was called to set loop start
        XCTAssertEqual(mockDelegate.setLoopStartCallCount, 1, "Delegate should have been called to set loop start")
    }

    func testSetLoopEndButtonAction() {
        let setLoopEndButton = controls.subviews.compactMap { $0 as? NSButton }.first { $0.action == #selector(controls.setLoopEnd) }
        XCTAssertNotNil(setLoopEndButton, "Set Loop End button should be found")

        // Simulate button click
        setLoopEndButton?.performClick()

        // Verify delegate was called to set loop end
        XCTAssertEqual(mockDelegate.setLoopEndCallCount, 1, "Delegate should have been called to set loop end")
    }

    func testClearLoopButtonAction() {
        let clearLoopButton = controls.subviews.compactMap { $0 as? NSButton }.first { $0.action == #selector(controls.clearLoop) }
        XCTAssertNotNil(clearLoopButton, "Clear Loop button should be found")

        // Simulate button click
        clearLoopButton?.performClick()

        // Verify delegate was called to clear loop
        XCTAssertEqual(mockDelegate.clearLoopCallCount, 1, "Delegate should have been called to clear loop")
    }

    func testLoopControlButtonsPositioning() {
        let buttons = controls.subviews.compactMap { $0 as? NSButton }
        let buttonFrames = buttons.map { $0.frame.origin.x }

        let setLoopStartButton = buttons.first { $0.action == #selector(controls.setLoopStart) }
        let setLoopEndButton = buttons.first { $0.action == #selector(controls.setLoopEnd) }
        let clearLoopButton = buttons.first { $0.action == #selector(controls.clearLoop) }

        XCTAssertNotNil(setLoopStartButton, "Set Loop Start button should exist")
        XCTAssertNotNil(setLoopEndButton, "Set Loop End button should exist")
        XCTAssertNotNil(clearLoopButton, "Clear Loop button should exist")

        // Verify buttons are positioned after frame step buttons but before position slider
        let slider = controls.subviews.first { $0 is NSSlider }
        XCTAssertNotNil(slider, "Position slider should exist")

        let sliderX = slider!.frame.origin.x

        XCTAssertTrue(setLoopStartButton!.frame.origin.x < setLoopEndButton!.frame.origin.x, "Set Loop Start should come before Set Loop End")
        XCTAssertTrue(setLoopEndButton!.frame.origin.x < clearLoopButton!.frame.origin.x, "Set Loop End should come before Clear Loop")
        XCTAssertTrue(clearLoopButton!.frame.origin.x < sliderX, "Clear Loop should come before position slider")
    }

    func testLoopDropdownExists() {
        let buttons = controls.subviews.compactMap { $0 as? NSPopUpButton }
        let loopDropdown = buttons.first { $0.title.contains("Loop") || $0.toolTip?.contains("Loop") ?? false }
        XCTAssertNotNil(loopDropdown, "Loop dropdown should exist")
    }

    func testLoopDropdownKeyboardShortcuts() async {
        // Test Cmd+[ for set loop start
        let keyLeft = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "[",
            charactersIgnoringModifiers: "[",
            isARepeat: false,
            keyCode: 123
        )

        controls.keyDown(with: keyLeft!)

        // Verify delegate was called
        XCTAssertEqual(mockDelegate.setLoopStartCallCount, 1, "Cmd+[ should trigger set loop start")

        // Test Cmd+] for set loop end
        let keyRight = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "]",
            charactersIgnoringModifiers: "]",
            isARepeat: false,
            keyCode: 124
        )

        controls.keyDown(with: keyRight!)

        // Verify delegate was called
        XCTAssertEqual(mockDelegate.setLoopEndCallCount, 1, "Cmd+] should trigger set loop end")

        // Test Cmd+L for clear loop
        let keyL = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "l",
            charactersIgnoringModifiers: "l",
            isARepeat: false,
            keyCode: 37
        )

        controls.keyDown(with: keyL!)

        // Verify delegate was called
        XCTAssertEqual(mockDelegate.clearLoopCallCount, 1, "Cmd+L should trigger clear loop")
    }
}

// MARK: - Enhanced Mock Delegate

class MockPlaybackControlsDelegate: PlaybackControlsDelegate {
    var stepForwardCallCount = 0
    var stepBackwardCallCount = 0
    var setLoopStartCallCount = 0
    var setLoopEndCallCount = 0
    var clearLoopCallCount = 0
    var lastSeekAmount: Double = 0.0
    var lastPosition: Double = 0.0

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
        lastPosition = position
    }

    func playbackControlsSetLoopStart(_ controls: PlaybackControls) {
        setLoopStartCallCount += 1
    }

    func playbackControlsSetLoopEnd(_ controls: PlaybackControls) {
        setLoopEndCallCount += 1
    }

    func playbackControlsClearLoop(_ controls: PlaybackControls) {
        clearLoopCallCount += 1
    }
}