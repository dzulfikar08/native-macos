import XCTest
@testable import OpenScreen

final class RecordingControllerTests: XCTestCase {
    @MainActor
    func testStartRecordingWithDisplay() async throws {
        let controller = RecordingController()
        let displayID = CGMainDisplayID()

        let url = try await controller.startRecording(displayID: displayID)

        // Verify recording started by checking URL is returned
        XCTAssertNotNil(url)

        // Clean up - stop recording if it started
        try? await controller.stopRecording()
    }
}
