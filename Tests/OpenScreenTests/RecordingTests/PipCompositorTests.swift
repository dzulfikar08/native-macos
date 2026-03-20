import XCTest
import CoreVideo
@testable import native_macos

final class PipCompositorTests: XCTestCase {
    func testCalculateRectSingleMode() {
        let compositor = PipCompositor()
        let size = CGSize(width: 1920, height: 1080)
        let rect = compositor.calculateRect(for: 0, mode: .single, in: size)

        XCTAssertEqual(rect, CGRect(x: 0, y: 0, width: 1920, height: 1080))
    }

    func testCalculateRectDualMode() {
        let compositor = PipCompositor()
        let size = CGSize(width: 1920, height: 1080)

        // Main camera
        let mainRect = compositor.calculateRect(for: 0, mode: .dual(main: 0, overlay: 1), in: size)
        XCTAssertEqual(mainRect.width, 1440, accuracy: 1.0)  // 75% width
        XCTAssertEqual(mainRect.height, 1080)

        // Overlay camera
        let overlayRect = compositor.calculateRect(for: 1, mode: .dual(main: 0, overlay: 1), in: size)
        XCTAssertEqual(overlayRect.width, 480, accuracy: 1.0)  // 25% width
        XCTAssertEqual(overlayRect.height, 270, accuracy: 1.0)  // 25% height
        XCTAssertEqual(overlayRect.origin.x, 1440, accuracy: 1.0)  // Top-right
    }

    func testCalculateRectQuadMode() {
        let compositor = PipCompositor()
        let size = CGSize(width: 1920, height: 1080)

        // All cameras should be 50% width, 50% height
        for index in 0..<4 {
            let rect = compositor.calculateRect(for: index, mode: .quad, in: size)
            XCTAssertEqual(rect.width, 960, accuracy: 1.0)
            XCTAssertEqual(rect.height, 540, accuracy: 1.0)
        }
    }
}
