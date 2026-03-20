import XCTest
@testable import OpenScreen

final class DisplayItemTests: XCTestCase {
    func testDisplayItemCreation() {
        // Arrange & Act
        let displayItem = DisplayItem(
            id: 123,
            name: "Main Display",
            width: 1920,
            height: 1080,
            thumbnail: nil
        )

        // Assert
        XCTAssertEqual(displayItem.id, 123, "Display ID should be stored correctly")
        XCTAssertEqual(displayItem.name, "Main Display", "Display name should be stored correctly")
        XCTAssertEqual(displayItem.width, 1920, "Display width should be stored correctly")
        XCTAssertEqual(displayItem.height, 1080, "Display height should be stored correctly")
        XCTAssertNil(displayItem.thumbnail, "Thumbnail should be nil when not provided")
        XCTAssertEqual(displayItem.resolution, "1920 × 1080", "Resolution should format correctly")
    }
}
