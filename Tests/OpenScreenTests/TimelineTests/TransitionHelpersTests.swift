import XCTest
import AppKit
import CoreMedia
@testable import OpenScreen

@MainActor
final class TransitionHelpersTests: XCTestCase {
    func testFormatDurationSeconds() {
        let time1 = CMTime(seconds: 0.5, preferredTimescale: 600)
        XCTAssertEqual(formatDuration(time1), "0.5s")
    }

    func testFormatDurationMinutes() {
        let time2 = CMTime(seconds: 90.0, preferredTimescale: 600)
        XCTAssertEqual(formatDuration(time2), "1:30")
    }

    func testCalculateOverlap() {
        let leading = TestDataFactory.makeTestVideoClip(
            name: "Leading",
            sourceDuration: 3,
            timelineStart: CMTime(seconds: 0, preferredTimescale: 600)
        )

        let trailing = TestDataFactory.makeTestVideoClip(
            name: "Trailing",
            sourceDuration: 3,
            timelineStart: CMTime(seconds: 2, preferredTimescale: 600)
        )

        let overlap = calculateOverlap(leading: leading, trailing: trailing)
        let expectedOverlap = CMTime(seconds: 1.0, preferredTimescale: 600)
        XCTAssertEqual(overlap, expectedOverlap)
    }

    func testCalculateOverlapNoOverlap() {
        let leading = TestDataFactory.makeTestVideoClip(
            name: "Leading",
            sourceDuration: 2,
            timelineStart: CMTime(seconds: 0, preferredTimescale: 600)
        )

        let trailing = TestDataFactory.makeTestVideoClip(
            name: "Trailing",
            sourceDuration: 2,
            timelineStart: CMTime(seconds: 3, preferredTimescale: 600)
        )

        let overlap = calculateOverlap(leading: leading, trailing: trailing)
        XCTAssertEqual(overlap, .zero)
    }
}
