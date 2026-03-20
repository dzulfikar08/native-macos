import XCTest
@testable import OpenScreen

@MainActor
final class SourceSelectorWindowControllerTests: XCTestCase {
    func testWindowControllerInitialization() {
        let controller = SourceSelectorWindowController()

        XCTAssertNotNil(controller.window)
        XCTAssertEqual(controller.window?.title, "Select Video Source")
    }
}
