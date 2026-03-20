import XCTest
@testable import OpenScreen
import Foundation

final class HistoryLimitTests: XCTestCase {
    func testLimitTypesExist() {
        let limit1 = HistoryLimit.unlimited
        let limit2 = HistoryLimit.fixedCount(100)
        let limit3 = HistoryLimit.timeWindow(600)
        let limit4 = HistoryLimit.hybrid(maxOps: 100, timeWindow: 600)
        // If compiles, types exist
        XCTAssertTrue(true)
    }

    func testHybridLimitHasCorrectValues() {
        if case .hybrid(let maxOps, let timeWindow) = HistoryLimit.hybrid(maxOps: 100, timeWindow: 600) {
            XCTAssertEqual(maxOps, 100)
            XCTAssertEqual(timeWindow, 600.0)
        } else {
            XCTFail("Should be hybrid case")
        }
    }
}
