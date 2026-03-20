import XCTest
@testable import OpenScreen

final class RecordingErrorTests: XCTestCase {
    func testPermissionDeniedMessage() {
        let error = RecordingError.permissionDenied(type: .screenRecording)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Screen recording permission"))
    }

    func testDiskSpaceErrorFormat() {
        let error = RecordingError.diskSpaceInsufficient(
            required: 5_000_000_000,  // 5GB
            available: 1_000_000_000   // 1GB
        )
        let description = error.errorDescription!
        XCTAssertTrue(description.contains("5.0"))
        XCTAssertTrue(description.contains("1.0"))
    }

    func testRecoverySuggestion() {
        let error = RecordingError.noDisplayAvailable
        XCTAssertNotNil(error.recoverySuggestion)
        XCTAssertNotNil(error.description)
    }

    func testAudioPermissionDeniedMessage() {
        let error = RecordingError.permissionDenied(type: .audio)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Audio recording permission"))
    }

    func testCodecNotAvailableMessage() {
        let error = RecordingError.codecNotAvailable
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("codec"))
    }

    func testRecordingInterruptedMessage() {
        let error = RecordingError.recordingInterrupted
        XCTAssertNotNil(error.errorDescription)
        XCTAssertNotNil(error.recoverySuggestion)
    }

    func testDiskSpaceEdgeCases() {
        // Test zero values
        let zeroError = RecordingError.diskSpaceInsufficient(required: 0, available: 0)
        XCTAssertNotNil(zeroError.errorDescription)

        // Test large values (1TB)
        let largeError = RecordingError.diskSpaceInsufficient(
            required: 1_000_000_000_000,
            available: 500_000_000_000
        )
        let description = largeError.errorDescription!
        XCTAssertTrue(description.contains("1000.0"))
    }
}
