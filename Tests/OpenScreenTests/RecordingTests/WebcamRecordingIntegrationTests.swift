import XCTest
import AVFoundation
@testable import OpenScreen

final class WebcamRecordingIntegrationTests: XCTestCase {
    func testFullWebcamRecordingFlow() async throws {
        try XCTSkipIf(true, "Integration test - requires actual hardware")

        // 1. Enumerate cameras
        let cameras = CameraDevice.enumerateCameras()
        XCTAssertTrue(cameras.count >= 1, "Need at least 1 camera")

        // 2. Create settings
        let settings = WebcamRecordingSettings(
            selectedCameras: [cameras[0]],
            compositingMode: .single,
            qualityPreset: .high,
            audioSettings: .init(
                systemAudioEnabled: false,
                microphoneEnabled: true,
                systemVolume: 1.0,
                microphoneVolume: 1.0
            ),
            codec: .h264
        )

        // 3. Create recorder
        let recorder = WebcamRecorder()
        let config = WebcamRecorder.WebcamRecordingConfig(
            cameras: settings.selectedCameras,
            compositingMode: settings.compositingMode,
            videoSettings: .init(
                resolution: settings.qualityPreset.resolution,
                frameRate: settings.qualityPreset.framerate,
                bitrate: settings.qualityPreset.bitrate
            ),
            audioSettings: settings.audioSettings,
            codec: settings.codec
        )

        // 4. Start recording
        let url = URL(fileURLWithPath: "/tmp/integration_test.mov")
        try await recorder.startRecording(to: url, config: config)
        XCTAssertTrue(recorder.isRecording)

        // 5. Record for 2 seconds
        try await Task.sleep(nanoseconds: 2_000_000_000)

        // 6. Stop recording
        let output = try await recorder.stopRecording()
        XCTAssertFalse(recorder.isRecording)

        // 7. Verify output file
        XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))

        let asset = AVAsset(url: output)
        XCTAssertFalse(asset.tracks(withMediaCharacteristic: .visual).isEmpty)
        XCTAssertFalse(asset.tracks(withMediaCharacteristic: .audible).isEmpty)

        // 8. Verify duration (should be ~2 seconds)
        let duration = asset.duration.seconds
        XCTAssertGreaterThan(duration, 1.5)
        XCTAssertLessThan(duration, 2.5)

        // Cleanup
        try? FileManager.default.removeItem(at: output)
    }
}
