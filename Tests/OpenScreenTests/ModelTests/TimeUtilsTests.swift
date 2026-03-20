import XCTest
import CoreMedia
@testable import OpenScreen

final class TimeUtilsTests: XCTestCase {
    func testFormatTimeSeconds() {
        let time = CMTime(seconds: 45, preferredTimescale: 600)
        XCTAssertEqual(TimeUtils.formatTime(time), "00:45")
    }

    func testFormatTimeMinutes() {
        let time = CMTime(seconds: 125, preferredTimescale: 600)
        XCTAssertEqual(TimeUtils.formatTime(time), "02:05")
    }

    func testFormatTimeHours() {
        let time = CMTime(seconds: 3661, preferredTimescale: 600)
        XCTAssertEqual(TimeUtils.formatTime(time), "01:01:01")
    }

    func testFormatDuration() {
        let time = CMTime(seconds: 90, preferredTimescale: 600)
        XCTAssertEqual(TimeUtils.formatDuration(time), "1m 30s")
    }

    func testFormatTimeZero() {
        let time = CMTime(seconds: 0, preferredTimescale: 600)
        XCTAssertEqual(TimeUtils.formatTime(time), "00:00")
    }

    func testFormatTimeMinuteBoundary() {
        let time = CMTime(seconds: 60, preferredTimescale: 600)
        XCTAssertEqual(TimeUtils.formatTime(time), "01:00")
    }

    func testFormatTimeHourBoundary() {
        let time = CMTime(seconds: 3600, preferredTimescale: 600)
        XCTAssertEqual(TimeUtils.formatTime(time), "01:00:00")
    }

    func testFormatDurationZero() {
        let time = CMTime(seconds: 0, preferredTimescale: 600)
        XCTAssertEqual(TimeUtils.formatDuration(time), "0s")
    }

    func testFormatTimeInterval() {
        XCTAssertEqual(TimeUtils.formatTimeInterval(45), "00:45")
        XCTAssertEqual(TimeUtils.formatTimeInterval(125), "02:05")
        XCTAssertEqual(TimeUtils.formatTimeInterval(3661), "01:01:01")
    }
}
