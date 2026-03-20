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
}
