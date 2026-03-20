import XCTest
import CoreMedia
@testable import OpenScreen

final class SnapPointTests: XCTestCase {
    // MARK: - Initialization Tests

    func testSnapPointInitialization() {
        let time = CMTime(seconds: 5.0, preferredTimescale: 600)
        let snapPoint = SnapPoint(position: time, type: .clipEdge, source: "Test Clip")

        XCTAssertEqual(snapPoint.position, time)
        XCTAssertEqual(snapPoint.type, .clipEdge)
        XCTAssertEqual(snapPoint.source, "Test Clip")
    }

    func testSnapPointWithNilSource() {
        let time = CMTime(seconds: 1.0, preferredTimescale: 600)
        let snapPoint = SnapPoint(position: time, type: .playhead)

        XCTAssertNil(snapPoint.source)
        XCTAssertEqual(snapPoint.type, .playhead)
    }

    // MARK: - Validation Tests

    func testSnapPointRejectsInvalidCMTime() {
        let invalidTime = CMTime.invalid
        XCTAssertFalse(invalidTime.isValid)

        // Should trap precondition
        XCTAssertFatalError {
            _ = SnapPoint(position: invalidTime, type: .clipEdge)
        }
    }

    func testSnapPointRejectsNegativeTime() {
        let negativeTime = CMTime(seconds: -1.0, preferredTimescale: 600)

        // Should trap precondition
        XCTAssertFatalError {
            _ = SnapPoint(position: negativeTime, type: .clipEdge)
        }
    }

    func testSnapPointAcceptsZeroTime() {
        let zeroTime = CMTime.zero
        let snapPoint = SnapPoint(position: zeroTime, type: .trackBoundary)

        XCTAssertEqual(snapPoint.position, zeroTime)
        XCTAssertTrue(CMTimeGetSeconds(snapPoint.position) == 0)
    }

    // MARK: - Equality Tests

    func testSnapPointTypeEquatable() {
        XCTAssertEqual(SnapPointType.clipEdge, .clipEdge)
        XCTAssertNotEqual(SnapPointType.clipEdge, .playhead)
    }

    func testSnapPointEquatable() {
        let time1 = CMTime(seconds: 5.0, preferredTimescale: 600)
        let time2 = CMTime(seconds: 5.0, preferredTimescale: 600)
        let time3 = CMTime(seconds: 6.0, preferredTimescale: 600)

        let snap1 = SnapPoint(position: time1, type: .clipEdge, source: "Clip A")
        let snap2 = SnapPoint(position: time2, type: .clipEdge, source: "Clip A")
        let snap3 = SnapPoint(position: time3, type: .clipEdge, source: "Clip A")

        XCTAssertEqual(snap1, snap2)
        XCTAssertNotEqual(snap1, snap3)
    }

    // MARK: - Different Timescales Tests

    func testSnapPointWithDifferentTimescales() {
        let time600 = CMTime(seconds: 1.0, preferredTimescale: 600)
        let time90000 = CMTime(seconds: 1.0, preferredTimescale: 90000)

        let snap600 = SnapPoint(position: time600, type: .timeIncrement)
        let snap90000 = SnapPoint(position: time90000, type: .timeIncrement)

        // Same time value, different timescales - should be equal
        XCTAssertEqual(CMTimeGetSeconds(snap600.position), CMTimeGetSeconds(snap90000.position), accuracy: 0.001)
    }
}
