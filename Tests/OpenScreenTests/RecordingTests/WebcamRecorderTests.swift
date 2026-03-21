import XCTest
import AVFoundation
@testable import OpenScreen

final class WebcamRecorderTests: XCTestCase {
    func testWebcamRecorderConformsToRecorder() {
        let recorder: any Recorder = WebcamRecorder()
        XCTAssertTrue(recorder is WebcamRecorder)
    }

    func testWebcamRecorderIsRecording() async throws {
        try XCTSkipIf(true, "Skipping hardware-dependent test in unit tests")

        let recorder = WebcamRecorder()
        XCTAssertFalse(recorder.isRecording)

        let cameras = CameraDevice.enumerateCameras()
        guard !cameras.isEmpty else {
            XCTSkip("No cameras available")
            return
        }

        let config = WebcamRecorder.Config(
            cameras: [cameras[0]],
            compositingMode: .single,
            videoSettings: .init(),
            audioSettings: .init(),
            codec: .h264
        )

        let url = URL(fileURLWithPath: "/tmp/test_webcam.mov")

        try await recorder.startRecording(to: url, config: config)
        XCTAssertTrue(recorder.isRecording)

        try await recorder.stopRecording()
        XCTAssertFalse(recorder.isRecording)
    }
}
