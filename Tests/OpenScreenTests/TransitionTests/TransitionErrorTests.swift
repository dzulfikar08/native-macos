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
        XCTAssertTrue(description?.contains("exceeds available clip overlap") ?? false)
    }

    func testInvalidParametersDescription() {
        let error = TransitionError.invalidParameters(reason: "Missing required field")
        let description = error.errorDescription

        XCTAssertEqual(description, "Invalid transition parameters: Missing required field")
    }

    func testClipsNotFoundDescription() {
        let leadingID = UUID()
        let trailingID = UUID()
        let error = TransitionError.clipsNotFound(leadingClipID: leadingID, trailingClipID: trailingID)
        let description = error.errorDescription

        XCTAssertTrue(description?.contains("leading clip") ?? false)
        XCTAssertTrue(description?.contains("trailing clip") ?? false)
    }

    func testClipsNotFoundDescription_OnlyLeading() {
        let leadingID = UUID()
        let error = TransitionError.clipsNotFound(leadingClipID: leadingID, trailingClipID: nil)
        let description = error.errorDescription

        XCTAssertTrue(description?.contains("leading clip") ?? false)
        XCTAssertFalse(description?.contains("trailing clip") ?? false)
    }

    func testClipsNotFoundDescription_OnlyTrailing() {
        let trailingID = UUID()
        let error = TransitionError.clipsNotFound(leadingClipID: nil, trailingClipID: trailingID)
        let description = error.errorDescription

        XCTAssertFalse(description?.contains("leading clip") ?? false)
        XCTAssertTrue(description?.contains("trailing clip") ?? false)
    }

    func testInsufficientOverlapDescription() {
        let minimumRequired = CMTime(seconds: 1.0, preferredTimescale: 600)
        let available = CMTime(seconds: 0.5, preferredTimescale: 600)
        let error = TransitionError.insufficientOverlap(minimumRequired: minimumRequired, available: available)
        let description = error.errorDescription

        XCTAssertTrue(description?.contains("0.5") ?? false)
        XCTAssertTrue(description?.contains("1.0") ?? false)
        XCTAssertTrue(description?.contains("Insufficient clip overlap") ?? false)
    }

    func testParameterOutOfRangeDescription() {
        let error = TransitionError.parameterOutOfRange("intensity", validRange: 0.0...1.0)
        let description = error.errorDescription

        XCTAssertEqual(description, "Parameter 'intensity' out of range: must be between 0.0 and 1.0")
    }

    func testTransitionOverlapDescription() {
        let id = UUID()
        let error = TransitionError.transitionOverlap(id)
        let description = error.errorDescription

        XCTAssertTrue(description?.contains(id.uuidString) ?? false)
        XCTAssertTrue(description?.contains("overlap with existing transition") ?? false)
    }

    // MARK: - Recovery Suggestion Tests

    func testDurationExceedsOverlapRecovery() {
        let error = TransitionError.durationExceedsOverlap(
            available: CMTime(seconds: 1.0, preferredTimescale: 600),
            requested: CMTime(seconds: 2.0, preferredTimescale: 600)
        )
        XCTAssertEqual(error.recoverySuggestion, "Reduce transition duration or increase clip overlap")
    }

    func testInvalidParametersRecovery() {
        let error = TransitionError.invalidParameters(reason: "Missing required field")
        XCTAssertEqual(error.recoverySuggestion, "Check transition parameters and try again")
    }

    func testClipsNotFoundRecovery() {
        let error = TransitionError.clipsNotFound(
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )
        XCTAssertEqual(error.recoverySuggestion, "Ensure both clips exist in timeline")
    }

    func testInsufficientOverlapRecovery() {
        let error = TransitionError.insufficientOverlap(
            minimumRequired: CMTime(seconds: 1.0, preferredTimescale: 600),
            available: CMTime(seconds: 0.5, preferredTimescale: 600)
        )
        XCTAssertEqual(error.recoverySuggestion, "Increase overlap between clips or use shorter transition")
    }

    func testParameterOutOfRangeRecovery() {
        let error = TransitionError.parameterOutOfRange("intensity", validRange: 0.0...1.0)
        XCTAssertEqual(error.recoverySuggestion, "Adjust parameter to be between 0.0 and 1.0")
    }

    func testTransitionOverlapRecovery() {
        let error = TransitionError.transitionOverlap(UUID())
        XCTAssertEqual(error.recoverySuggestion, "Remove or adjust the overlapping transition")
    }

    // MARK: - Equatable Tests

    func testEquatableDurationExceedsOverlap() {
        let available = CMTime(seconds: 1.0, preferredTimescale: 600)
        let requested = CMTime(seconds: 2.0, preferredTimescale: 600)
        let error1 = TransitionError.durationExceedsOverlap(available: available, requested: requested)
        let error2 = TransitionError.durationExceedsOverlap(available: available, requested: requested)

        XCTAssertEqual(error1, error2)
    }

    func testNotEqualDurationExceedsOverlap() {
        let error1 = TransitionError.durationExceedsOverlap(
            available: CMTime(seconds: 1.0, preferredTimescale: 600),
            requested: CMTime(seconds: 2.0, preferredTimescale: 600)
        )
        let error2 = TransitionError.durationExceedsOverlap(
            available: CMTime(seconds: 1.5, preferredTimescale: 600),
            requested: CMTime(seconds: 2.0, preferredTimescale: 600)
        )

        XCTAssertNotEqual(error1, error2)
    }

    func testEquatableInvalidParameters() {
        let error1 = TransitionError.invalidParameters(reason: "test")
        let error2 = TransitionError.invalidParameters(reason: "test")

        XCTAssertEqual(error1, error2)
    }

    func testNotEqualInvalidParameters() {
        let error1 = TransitionError.invalidParameters(reason: "test1")
        let error2 = TransitionError.invalidParameters(reason: "test2")

        XCTAssertNotEqual(error1, error2)
    }

    func testEquatableClipsNotFound() {
        let id1 = UUID()
        let id2 = UUID()
        let error1 = TransitionError.clipsNotFound(leadingClipID: id1, trailingClipID: id2)
        let error2 = TransitionError.clipsNotFound(leadingClipID: id1, trailingClipID: id2)

        XCTAssertEqual(error1, error2)
    }

    func testNotEqualClipsNotFound() {
        let error1 = TransitionError.clipsNotFound(
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )
        let error2 = TransitionError.clipsNotFound(
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )

        XCTAssertNotEqual(error1, error2)
    }

    func testEquatableInsufficientOverlap() {
        let minRequired = CMTime(seconds: 1.0, preferredTimescale: 600)
        let available = CMTime(seconds: 0.5, preferredTimescale: 600)
        let error1 = TransitionError.insufficientOverlap(minimumRequired: minRequired, available: available)
        let error2 = TransitionError.insufficientOverlap(minimumRequired: minRequired, available: available)

        XCTAssertEqual(error1, error2)
    }

    func testNotEqualInsufficientOverlap() {
        let minRequired = CMTime(seconds: 1.0, preferredTimescale: 600)
        let error1 = TransitionError.insufficientOverlap(
            minimumRequired: minRequired,
            available: CMTime(seconds: 0.5, preferredTimescale: 600)
        )
        let error2 = TransitionError.insufficientOverlap(
            minimumRequired: minRequired,
            available: CMTime(seconds: 0.3, preferredTimescale: 600)
        )

        XCTAssertNotEqual(error1, error2)
    }

    func testEquatableParameterOutOfRange() {
        let error1 = TransitionError.parameterOutOfRange("intensity", validRange: 0.0...1.0)
        let error2 = TransitionError.parameterOutOfRange("intensity", validRange: 0.0...1.0)

        XCTAssertEqual(error1, error2)
    }

    func testNotEqualParameterOutOfRange() {
        let error1 = TransitionError.parameterOutOfRange("intensity", validRange: 0.0...1.0)
        let error2 = TransitionError.parameterOutOfRange("intensity", validRange: 0.0...2.0)

        XCTAssertNotEqual(error1, error2)
    }

    func testEquatableTransitionOverlap() {
        let id = UUID()
        let error1 = TransitionError.transitionOverlap(id)
        let error2 = TransitionError.transitionOverlap(id)

        XCTAssertEqual(error1, error2)
    }

    func testNotEqualTransitionOverlap() {
        let error1 = TransitionError.transitionOverlap(UUID())
        let error2 = TransitionError.transitionOverlap(UUID())

        XCTAssertNotEqual(error1, error2)
    }

    func testNotEqualDifferentErrorTypes() {
        let error1 = TransitionError.invalidParameters(reason: "test")
        let error2 = TransitionError.clipsNotFound(
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )

        XCTAssertNotEqual(error1, error2)
    }
}
