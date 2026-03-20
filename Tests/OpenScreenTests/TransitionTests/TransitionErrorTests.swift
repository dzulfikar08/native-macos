import XCTest
import CoreMedia
@testable import OpenScreen

final class TransitionErrorTests: XCTestCase {
    // MARK: - Error Description Tests

    func testDurationExceedsOverlapDescription() {
        let available = CMTime(seconds: 1.0, preferredTimescale: 600)
        let requested = CMTime(seconds: 2.0, preferredTimescale: 600)
        let error = TransitionError.durationExceedsOverlap(available: available, requested: requested)

        let description = error.errorDescription
        XCTAssertTrue(description?.contains("2.0") ?? false)
        XCTAssertTrue(description?.contains("1.0") ?? false)
    }

    func testInvalidParametersDescription() {
        let error = TransitionError.invalidParameters(reason: "softness out of range")
        let description = error.errorDescription

        XCTAssertTrue(description?.contains("softness out of range") ?? false)
    }

    func testClipsNotFoundDescription() {
        let leadingID = UUID()
        let error = TransitionError.clipsNotFound(leadingClipID: leadingID, trailingClipID: nil)
        let description = error.errorDescription

        XCTAssertTrue(description?.contains("leading clip") ?? false)
    }

    func testInsufficientOverlapDescription() {
        let minimum = CMTime(seconds: 0.5, preferredTimescale: 600)
        let available = CMTime(seconds: 0.2, preferredTimescale: 600)
        let error = TransitionError.insufficientOverlap(minimumRequired: minimum, available: available)

        let description = error.errorDescription
        XCTAssertTrue(description?.contains("0.2") ?? false)
        XCTAssertTrue(description?.contains("0.5") ?? false)
    }

    func testParameterOutOfRangeDescription() {
        let error = TransitionError.parameterOutOfRange("softness", validRange: 0.0...1.0)
        let description = error.errorDescription

        XCTAssertTrue(description?.contains("softness") ?? false)
        XCTAssertTrue(description?.contains("0") ?? false)
        XCTAssertTrue(description?.contains("1") ?? false)
    }

    // MARK: - Recovery Suggestion Tests

    func testDurationExceedsOverlapRecovery() {
        let error = TransitionError.durationExceedsOverlap(
            available: CMTime(seconds: 1.0, preferredTimescale: 600),
            requested: CMTime(seconds: 2.0, preferredTimescale: 600)
        )

        let suggestion = error.recoverySuggestion
        XCTAssertTrue(suggestion?.contains("Reduce") ?? false)
    }

    func testInvalidParametersRecovery() {
        let error = TransitionError.invalidParameters(reason: "test")
        let suggestion = error.recoverySuggestion

        XCTAssertTrue(suggestion?.contains("Check") ?? false)
    }

    // MARK: - Equatable Tests

    func testErrorEquality() {
        let error1 = TransitionError.invalidParameters(reason: "test")
        let error2 = TransitionError.invalidParameters(reason: "test")
        let error3 = TransitionError.invalidParameters(reason: "other")

        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
    }
}
