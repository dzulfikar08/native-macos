import XCTest
@testable import OpenScreen

@MainActor
final class WindowTrackerTests: XCTestCase {
    var tracker: WindowTracker!

    override func setUp() {
        super.setUp()
        tracker = WindowTracker()
    }

    override func tearDown() {
        tracker = nil
        super.tearDown()
    }

    func testWindowStateInitiallyUnknown() {
        XCTAssertNil(tracker.windowState[123])
    }

    func testStartTrackingInitializesState() {
        tracker.startTracking(windowIDs: [123, 456])

        XCTAssertEqual(tracker.windowState.count, 2)
    }

    func testDetectsClosedWindow() {
        var stateChangeCount = 0
        var capturedState: WindowTracker.WindowState?

        tracker.onWindowStateChanged = { windowID, state in
            stateChangeCount += 1
            capturedState = state
        }

        tracker.startTracking(windowIDs: [999999]) // Non-existent window

        // Wait for tracking to detect
        let expectation = XCTestExpectation(description: "State change detected")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)

        XCTAssertGreaterThanOrEqual(stateChangeCount, 1)
        if let state = capturedState {
            XCTAssertTrue(state == .closed || state == .onOtherSpace)
        }
    }
}
