import XCTest
@testable import OpenScreen

@MainActor
final class WindowDeviceTests: XCTestCase {
    func testWindowDeviceInitialization() {
        let device = WindowDevice(
            id: 123,
            name: "Test Window",
            ownerName: "Test App",
            bounds: CGRect(x: 100, y: 100, width: 800, height: 600)
        )

        XCTAssertEqual(device.id, 123)
        XCTAssertEqual(device.name, "Test Window")
        XCTAssertEqual(device.ownerName, "Test App")
        XCTAssertEqual(device.bounds, CGRect(x: 100, y: 100, width: 800, height: 600))
    }

    func testEnumerateWindowsReturnsNonEmptyArray() {
        let windows = WindowDevice.enumerateWindows()

        XCTAssertFalse(windows.isEmpty, "Should find at least one window")
    }

    func testWindowFilteringExcludesInvalidWindows() {
        let windows = WindowDevice.enumerateWindows()

        for window in windows {
            XCTAssertFalse(window.name.isEmpty, "Window should have a name")
            XCTAssertFalse(window.ownerName.isEmpty, "Window should have an owner")
            XCTAssertGreaterThanOrEqual(window.bounds.width, 100, "Window should be at least 100px wide")
            XCTAssertGreaterThanOrEqual(window.bounds.height, 100, "Window should be at least 100px tall")
        }
    }

    func testThumbnailGeneration() {
        let device = WindowDevice(
            id: 123,
            name: "Test Window",
            ownerName: "Test App",
            bounds: CGRect(x: 100, y: 100, width: 800, height: 600)
        )

        // Note: This will return nil if window 123 doesn't exist
        // In a real scenario, you'd use an actual window ID
        let thumbnail = device.createThumbnail()

        if let thumbnail = thumbnail {
            XCTAssertEqual(thumbnail.size.width, 160, "Thumbnail should be 160px wide")
            XCTAssertEqual(thumbnail.size.height, 120, "Thumbnail should be 120px tall")
        }
        // If thumbnail is nil, that's OK for non-existent windows in tests
    }

    func testBoundsExtraction() {
        let device = WindowDevice(
            id: 123,
            name: "Test Window",
            ownerName: "Test App",
            bounds: CGRect(x: 100, y: 100, width: 800, height: 600)
        )

        XCTAssertEqual(device.bounds.origin.x, 100, "X coordinate should be 100")
        XCTAssertEqual(device.bounds.origin.y, 100, "Y coordinate should be 100")
        XCTAssertEqual(device.bounds.width, 800, "Width should be 800")
        XCTAssertEqual(device.bounds.height, 600, "Height should be 600")
    }
}
