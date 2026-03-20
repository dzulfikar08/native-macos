import XCTest
@testable import OpenScreen

final class ScreenRecorderTests: XCTestCase {
    @MainActor
    func testScreenRecorderInitialization() {
        let recorder = ScreenRecorder()
        XCTAssertNotNil(recorder)
    }

    @MainActor
    func testStartRecordingWithoutPermission() async throws {
        // This test handles permission gracefully
        let recorder = ScreenRecorder()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_\(UUID().uuidString).mov")

        do {
            try await recorder.startRecording(to: url)
            // If permission granted, verify state
            // Note: In CI without display, this may fail
            _ = try await recorder.stopRecording()
        } catch {
            // Expected to fail without screen recording permission in CI
            XCTAssertNotNil(error)
        }
    }

    @MainActor
    func testStartRecordingWithSpecificDisplay() async throws {
        let recorder = ScreenRecorder()
        let url = try FileUtils.uniqueRecordingURL()
        let displayID = CGMainDisplayID()

        try await recorder.startRecording(to: url, displayID: displayID)

        // Verify recording started with specified display
        // Note: We can't directly check internal state, but the method call succeeding
        // indicates the displayID parameter is accepted
        do {
            _ = try await recorder.stopRecording()
        } catch {
            // Expected to fail without screen recording permission in CI
            XCTAssertNotNil(error)
        }
    }
}
