import XCTest
import CoreMedia
@testable import OpenScreen

final class SnapResultTests: XCTestCase {
    // MARK: - Initialization and Offset Calculation Tests

    func testSnapResultInitializationWithPositiveOffset() {
        let snapPoint = SnapPoint(position: CMTime(seconds: 5.0, preferredTimescale: 600), type: .clipEdge)
        let original = CMTime(seconds: 4.8, preferredTimescale: 600)
        let snapped = CMTime(seconds: 5.0, preferredTimescale: 600)

        let result = SnapResult(snapPoint: snapPoint, originalPosition: original, snappedPosition: snapped)

        XCTAssertEqual(result.snapPoint.type, .clipEdge)
        XCTAssertEqual(result.originalPosition, original)
        XCTAssertEqual(result.snappedPosition, snapped)
        XCTAssertEqual(result.offsetSeconds, 0.2, accuracy: 0.001)
    }

    func testSnapResultInitializationWithNegativeOffset() {
        let snapPoint = SnapPoint(position: CMTime(seconds: 5.0, preferredTimescale: 600), type: .timeIncrement)
        let original = CMTime(seconds: 5.3, preferredTimescale: 600)
        let snapped = CMTime(seconds: 5.0, preferredTimescale: 600)

        let result = SnapResult(snapPoint: snapPoint, originalPosition: original, snappedPosition: snapped)

        XCTAssertEqual(result.offsetSeconds, -0.3, accuracy: 0.001)
    }

    func testSnapResultWithZeroOffset() {
        let snapPoint = SnapPoint(position: CMTime(seconds: 10.0, preferredTimescale: 600), type: .playhead)
        let position = CMTime(seconds: 10.0, preferredTimescale: 600)

        let result = SnapResult(snapPoint: snapPoint, originalPosition: position, snappedPosition: position)

        XCTAssertEqual(result.offsetSeconds, 0.0, accuracy: 0.001)
        XCTAssertTrue(result.isWithinTolerance(0.5))
    }

    // MARK: - Validation Tests

    func testSnapResultRejectsInvalidOriginalPosition() {
        let snapPoint = SnapPoint(position: CMTime(seconds: 5.0, preferredTimescale: 600), type: .clipEdge)
        let invalid = CMTime.invalid
        let snapped = CMTime(seconds: 5.0, preferredTimescale: 600)

        XCTAssertFatalError {
            _ = SnapResult(snapPoint: snapPoint, originalPosition: invalid, snappedPosition: snapped)
        }
    }

    func testSnapResultRejectsInvalidSnappedPosition() {
        let snapPoint = SnapPoint(position: CMTime(seconds: 5.0, preferredTimescale: 600), type: .clipEdge)
        let original = CMTime(seconds: 4.8, preferredTimescale: 600)
        let invalid = CMTime.invalid

        XCTAssertFatalError {
            _ = SnapResult(snapPoint: snapPoint, originalPosition: original, snappedPosition: invalid)
        }
    }

    // MARK: - Tolerance Tests

    func testIsWithinTolerancePositive() {
        let snapPoint = SnapPoint(position: CMTime(seconds: 10.0, preferredTimescale: 600), type: .playhead)
        let original = CMTime(seconds: 9.5, preferredTimescale: 600)
        let snapped = CMTime(seconds: 10.0, preferredTimescale: 600)

        let result = SnapResult(snapPoint: snapPoint, originalPosition: original, snappedPosition: snapped)

        XCTAssertTrue(result.isWithinTolerance(0.5))
        XCTAssertTrue(result.isWithinTolerance(1.0))
        XCTAssertFalse(result.isWithinTolerance(0.3))
    }

    func testIsWithinToleranceNegative() {
        let snapPoint = SnapPoint(position: CMTime(seconds: 5.0, preferredTimescale: 600), type: .timeIncrement)
        let original = CMTime(seconds: 5.4, preferredTimescale: 600)
        let snapped = CMTime(seconds: 5.0, preferredTimescale: 600)

        let result = SnapResult(snapPoint: snapPoint, originalPosition: original, snappedPosition: snapped)

        XCTAssertTrue(result.isWithinTolerance(0.5))
        XCTAssertFalse(result.isWithinTolerance(0.3))
    }

    // MARK: - Offset Magnitude Tests

    func testOffsetMagnitudeWithLargeSnap() {
        let snapPoint = SnapPoint(position: CMTime(seconds: 100.0, preferredTimescale: 600), type: .clipEdge)
        let original = CMTime(seconds: 90.0, preferredTimescale: 600)
        let snapped = CMTime(seconds: 100.0, preferredTimescale: 600)

        let result = SnapResult(snapPoint: snapPoint, originalPosition: original, snappedPosition: snapped)

        XCTAssertEqual(result.offsetSeconds, 10.0, accuracy: 0.01)
    }

    func testOffsetMagnitudeWithSmallSnap() {
        let snapPoint = SnapPoint(position: CMTime(seconds: 1.0, preferredTimescale: 600), type: .playhead)
        let original = CMTime(seconds: 0.99, preferredTimescale: 600)
        let snapped = CMTime(seconds: 1.0, preferredTimescale: 600)

        let result = SnapResult(snapPoint: snapPoint, originalPosition: original, snappedPosition: snapped)

        XCTAssertEqual(result.offsetSeconds, 0.01, accuracy: 0.001)
    }
}
