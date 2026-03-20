import XCTest
@testable import OpenScreen

final class NotificationExtensionsTests: XCTestCase {
    func testPlaybackStateChangeNotification() {
        // Test that playback state notification name is defined
        let notification = Notification.Name.playbackStateChanged
        XCTAssertEqual(notification.rawValue, "com.openscreen.playback.stateChanged")
    }

    func testTimelineSeekNotification() {
        // Test that timeline seek notification name is defined
        let notification = Notification.Name.timelineSeekPerformed
        XCTAssertEqual(notification.rawValue, "com.openscreen.timeline.seekPerformed")
    }

    func testRecordingNotification() {
        // Test that recording notification name is defined
        let notification = Notification.Name.recordingDidComplete
        XCTAssertEqual(notification.rawValue, "com.openscreen.recording.didComplete")
    }
}
