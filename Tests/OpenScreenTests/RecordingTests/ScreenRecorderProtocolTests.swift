import XCTest
import AVFoundation
@testable import OpenScreen

@MainActor
final class ScreenRecorderProtocolTests: XCTestCase {
    func testScreenRecorderConformsToRecorder() {
        let recorder: any Recorder = ScreenRecorder()
        XCTAssertTrue(recorder is ScreenRecorder)
    }

    func testScreenRecorderConfig() {
        let config = ScreenRecorder.Config(displayID: nil)
        XCTAssertNil(config.displayID)
    }

    func testScreenRecorderStartWithConfig() async throws {
        let recorder = ScreenRecorder()
        let config = ScreenRecorder.Config(displayID: nil)
        let url = URL(fileURLWithPath: "/tmp/test_screen.mov")

        try await recorder.startRecording(to: url, config: config)
        XCTAssertTrue(recorder.isRecording)

        try await recorder.stopRecording()
        XCTAssertFalse(recorder.isRecording)
    }
}
