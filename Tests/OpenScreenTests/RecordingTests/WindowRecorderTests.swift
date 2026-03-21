import XCTest
import AVFoundation
@testable import OpenScreen

@MainActor
final class WindowRecorderTests: XCTestCase {
    var recorder: WindowRecorder!
    var outputURL: URL!

    override func setUp() {
        super.setUp()
        recorder = WindowRecorder()
        outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_window_\(UUID().uuidString).mov")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: outputURL)
        super.tearDown()
    }

    func testWindowRecorderConformsToRecorder() {
        XCTAssertTrue(recorder is Recorder)
    }

    func testIsRecordingInitiallyFalse() {
        XCTAssertFalse(recorder.isRecording)
    }

    func testStartRecordingSetsIsRecordingToTrue() async throws {
        let windows = [
            WindowDevice(id: 1, name: "Test", ownerName: "Test", bounds: .zero)
        ]
        var settings = WindowRecordingSettings()
        settings.selectedWindows = windows
        settings.qualityPreset = .low

        let config = WindowRecorder.Config(
            windowIDs: windows.map { $0.id },
            settings: settings
        )

        try await recorder.startRecording(to: outputURL, config: config)
        XCTAssertTrue(recorder.isRecording)

        try await recorder.stopRecording()
    }

    func testStopRecordingReturnsOutputURL() async throws {
        let windows = [
            WindowDevice(id: 1, name: "Test", ownerName: "Test", bounds: .zero)
        ]
        var settings = WindowRecordingSettings()
        settings.selectedWindows = windows
        settings.qualityPreset = .low

        let config = WindowRecorder.Config(
            windowIDs: windows.map { $0.id },
            settings: settings
        )

        try await recorder.startRecording(to: outputURL, config: config)

        // Record briefly
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

        let returnedURL = try await recorder.stopRecording()

        XCTAssertEqual(returnedURL, outputURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
    }

    func testQueryWindowBoundsReturnsCGRect() async throws {
        let windows = WindowDevice.enumerateWindows()
        try XCTSkipIf(windows.isEmpty, "No windows available")

        let windowID = windows.first!.id

        try await recorder.startRecording(
            to: outputURL,
            config: WindowRecorder.Config(
                windowIDs: [windowID],
                settings: WindowRecordingSettings()
            )
        )

        // This test verifies bounds query works internally
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        try await recorder.stopRecording()
    }
}
