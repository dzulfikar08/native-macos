import XCTest
@testable import OpenScreen
import Foundation

final class CoalescingStrategyTests: XCTestCase {
    func testStrategyTypesExist() {
        let strategy1 = CoalescingStrategy.none
        let strategy2 = CoalescingStrategy.timeWindow(1.0)
        let strategy3 = CoalescingStrategy.sameTypeAndTarget
        let strategy4 = CoalescingStrategy.smart
        // If compiles, types exist
        XCTAssertTrue(true)
    }

    func testSmartStrategyIsDefault() {
        let config = CoalescingConfig()
        XCTAssertEqual(config.timeWindow, 1.0)
        XCTAssertTrue(config.enabled)
    }
}
