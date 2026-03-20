import XCTest
@testable import native_macos

final class MiniRecordingViewTests: XCTestCase {
    func testMiniViewCanBeCreated() {
        let miniView = MiniRecordingView()
        XCTAssertNotNil(miniView.window)
        XCTAssertEqual(miniView.window?.title, "Recording")
    }

    func testMiniViewPositionPersistence() {
        let miniView = MiniRecordingView()

        let testPosition = NSPoint(x: 100, y: 100)
        miniView.setFrameOrigin(testPosition)
        miniView.savePosition()

        let newView = MiniRecordingView()
        newView.restorePosition()

        XCTAssertEqual(newView.frame.origin, testPosition)
    }
}
