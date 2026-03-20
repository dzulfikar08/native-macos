import XCTest
@testable import OpenScreen

@MainActor
final class ScreenSourceViewControllerTests: XCTestCase {
    func testEnumerateDisplays() {
        let controller = ScreenSourceViewController()
        let displays = controller.enumerateDisplays()

        XCTAssertTrue(displays.count > 0, "Should detect at least one display")
        XCTAssertTrue(displays.contains { $0.name.contains("Display") })
    }
}
