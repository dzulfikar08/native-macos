import XCTest
import CoreGraphics
import CoreMedia
@testable import OpenScreen

final class ClipLayoutTests: XCTestCase {
    // MARK: - Initialization Tests

    func testClipLayoutInitializationWithDefaults() {
        let clipID = UUID()
        let frame = CGRect(x: 100, y: 0, width: 200, height: 60)
        let timeRange = CMTimeRange(
            start: CMTime(seconds: 0, preferredTimescale: 600),
            duration: CMTime(seconds: 5.0, preferredTimescale: 600)
        )

        let layout = ClipLayout(clipID: clipID, frame: frame, timeRange: timeRange)

        XCTAssertEqual(layout.clipID, clipID)
        XCTAssertEqual(layout.frame, frame)
        XCTAssertEqual(layout.timeRange, timeRange)
        XCTAssertTrue(layout.isDirty) // Default is dirty
    }

    func testClipLayoutInitializationNotDirty() {
        let layout = ClipLayout(
            clipID: UUID(),
            frame: CGRect(x: 50, y: 60, width: 150, height: 40),
            timeRange: CMTimeRange(
                start: CMTime(seconds: 2.0, preferredTimescale: 600),
                duration: CMTime(seconds: 3.0, preferredTimescale: 600)
            ),
            isDirty: false
        )

        XCTAssertFalse(layout.isDirty)
    }

    // MARK: - Validation Tests

    func testClipLayoutRejectsNegativeWidth() {
        let invalidFrame = CGRect(x: 0, y: 0, width: -10, height: 60)
        let validTimeRange = CMTimeRange.zero

        XCTAssertFatalError {
            _ = ClipLayout(clipID: UUID(), frame: invalidFrame, timeRange: validTimeRange)
        }
    }

    func testClipLayoutRejectsNegativeHeight() {
        let invalidFrame = CGRect(x: 0, y: 0, width: 200, height: -5)
        let validTimeRange = CMTimeRange.zero

        XCTAssertFatalError {
            _ = ClipLayout(clipID: UUID(), frame: invalidFrame, timeRange: validTimeRange)
        }
    }

    func testClipLayoutAcceptsZeroWidthAndHeight() {
        let zeroFrame = CGRect.zero
        let zeroTimeRange = CMTimeRange.zero

        let layout = ClipLayout(clipID: UUID(), frame: zeroFrame, timeRange: zeroTimeRange)

        XCTAssertEqual(layout.frame, .zero)
        XCTAssertEqual(layout.timeRange, .zero)
    }

    // MARK: - Computed Properties Tests

    func testClipLayoutComputedProperties() {
        let frame = CGRect(x: 100, y: 50, width: 200, height: 60)
        let timeRange = CMTimeRange(
            start: CMTime(seconds: 5.0, preferredTimescale: 600),
            duration: CMTime(seconds: 10.0, preferredTimescale: 600)
        )

        let layout = ClipLayout(clipID: UUID(), frame: frame, timeRange: timeRange)

        XCTAssertEqual(layout.x, 100)
        XCTAssertEqual(layout.y, 50)
        XCTAssertEqual(layout.width, 200)
        XCTAssertEqual(layout.height, 60)
        XCTAssertEqual(CMTimeGetSeconds(layout.startTime), 5.0, accuracy: 0.01)
        XCTAssertEqual(CMTimeGetSeconds(layout.duration), 10.0, accuracy: 0.01)
    }

    // MARK: - Dirty Flag Tests

    func testClipLayoutDirtyFlagCanBeMutated() {
        var layout = ClipLayout(clipID: UUID(), frame: .zero, timeRange: .zero)
        XCTAssertTrue(layout.isDirty)

        layout.isDirty = false
        XCTAssertFalse(layout.isDirty)
    }

    // MARK: - CMTimeRange.zero Extension Tests

    func testCMTimeRangeZeroExtension() {
        let zeroRange = CMTimeRange.zero

        XCTAssertEqual(CMTimeGetSeconds(zeroRange.start), 0.0, accuracy: 0.001)
        XCTAssertEqual(CMTimeGetSeconds(zeroRange.duration), 0.0, accuracy: 0.001)
    }

    // MARK: - Equality Tests

    func testClipLayoutEquality() {
        let clipID = UUID()
        let frame = CGRect(x: 100, y: 0, width: 200, height: 60)
        let timeRange = CMTimeRange(
            start: CMTime(seconds: 0, preferredTimescale: 600),
            duration: CMTime(seconds: 5.0, preferredTimescale: 600)
        )

        let layout1 = ClipLayout(clipID: clipID, frame: frame, timeRange: timeRange)
        let layout2 = ClipLayout(clipID: clipID, frame: frame, timeRange: timeRange)

        XCTAssertEqual(layout1.clipID, layout2.clipID)
        XCTAssertEqual(layout1.frame, layout2.frame)
        XCTAssertEqual(layout1.timeRange, layout2.timeRange)
    }
}
