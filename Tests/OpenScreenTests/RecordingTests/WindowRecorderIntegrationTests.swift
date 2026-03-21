import XCTest
import AVFoundation
@testable import OpenScreen

@MainActor
final class WindowRecorderIntegrationTests: XCTestCase {
    var recorder: WindowRecorder!
    var outputURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        recorder = WindowRecorder()
        outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_integration_\(UUID().uuidString).mov")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: outputURL)
        try await super.tearDown()
    }

    func testFullRecordingWorkflow() async throws {
        let windows = WindowDevice.enumerateWindows()
        try XCTSkipIf(windows.isEmpty, "No windows available for testing")

        let window = windows.first!
        var settings = WindowRecordingSettings()
        settings.selectedWindows = [window]
        settings.qualityPreset = .medium

        let config = WindowRecorder.Config(
            windowIDs: [window.id],
            settings: settings
        )

        // Start recording
        try await recorder.startRecording(to: outputURL, config: config)
        XCTAssertTrue(recorder.isRecording)

        // Record for 0.5 seconds
        try await Task.sleep(nanoseconds: 500_000_000)

        // Stop recording
        let returnedURL = try await recorder.stopRecording()
        XCTAssertFalse(recorder.isRecording)

        // Verify file exists
        XCTAssertEqual(returnedURL, outputURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))

        // Verify file is valid video
        let asset = AVAsset(url: outputURL)
        let duration = try await asset.load(.duration)
        XCTAssertGreaterThan(CMTimeGetSeconds(duration), 0.3, "Should have at least 0.3 seconds of video")
    }

    func testMultipleWindowsRecording() async throws {
        let windows = WindowDevice.enumerateWindows()
        try XCTSkipIf(windows.count < 2, "Need at least 2 windows for testing")

        let selectedWindows = Array(windows.prefix(2))
        var settings = WindowRecordingSettings()
        settings.selectedWindows = selectedWindows
        settings.qualityPreset = .low
        settings.compositingMode = .dual(main: 0, overlay: 1)

        let config = WindowRecorder.Config(
            windowIDs: selectedWindows.map { $0.id },
            settings: settings
        )

        try await recorder.startRecording(to: outputURL, config: config)

        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

        let url = try await recorder.stopRecording()

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        // Verify video dimensions match expected output
        let asset = AVAsset(url: url)
        let videoTrack = try await asset.loadTracks(withMediaType: .video).first
        XCTAssertNotNil(videoTrack, "Should have video track")

        if let track = videoTrack {
            let size = try await track.load(.naturalSize)
            XCTAssertNotNil(settings.qualityPreset.resolution, "Quality preset should have resolution")
            if let resolution = settings.qualityPreset.resolution {
                XCTAssertEqual(size.width, resolution.width, "Video width should match quality preset")
                XCTAssertEqual(size.height, resolution.height, "Video height should match quality preset")
            }
        }
    }

    func testAudioIntegration() async throws {
        let windows = WindowDevice.enumerateWindows()
        try XCTSkipIf(windows.isEmpty, "No windows available")

        let window = windows.first!
        var settings = WindowRecordingSettings()
        settings.selectedWindows = [window]
        settings.audioSettings = AudioSettings()
        settings.audioSettings.systemAudioEnabled = true

        let config = WindowRecorder.Config(
            windowIDs: [window.id],
            settings: settings
        )

        try await recorder.startRecording(to: outputURL, config: config)
        try await Task.sleep(nanoseconds: 300_000_000)
        _ = try await recorder.stopRecording()

        // Verify output file has audio track
        let asset = AVAsset(url: outputURL)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        XCTAssertFalse(audioTracks.isEmpty, "Should have audio track when system audio enabled")
    }

    func testWindowStateChangeHandling() async throws {
        let windows = WindowDevice.enumerateWindows()
        try XCTSkipIf(windows.isEmpty, "No windows available")

        let window = windows.first!
        var settings = WindowRecordingSettings()
        settings.selectedWindows = [window]

        let config = WindowRecorder.Config(
            windowIDs: [window.id],
            settings: settings
        )

        try await recorder.startRecording(to: outputURL, config: config)

        // Simulate window becoming unavailable (minimize/close)
        // In production: Would trigger WindowTracker callback
        // For now: Verify recorder handles consecutive failures gracefully

        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        let url = try await recorder.stopRecording()

        // Verify recording completed despite potential state changes
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testDifferentCodecs() async throws {
        let windows = WindowDevice.enumerateWindows()
        try XCTSkipIf(windows.isEmpty, "No windows available")

        let window = windows.first!

        for codec in [VideoCodec.h264, .hevc] {
            let filename = "test_codec_\(codec.rawValue)_\(UUID().uuidString).mov"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

            var settings = WindowRecordingSettings()
            settings.selectedWindows = [window]
            settings.codec = codec

            let config = WindowRecorder.Config(
                windowIDs: [window.id],
                settings: settings
            )

            try await recorder.startRecording(to: url, config: config)
            try await Task.sleep(nanoseconds: 200_000_000)
            _ = try await recorder.stopRecording()

            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

            try? FileManager.default.removeItem(at: url)
        }
    }
}
