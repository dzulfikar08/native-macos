import XCTest
@testable import OpenScreen
import Metal

@available(macOS 13.0, *)
final class MetalRendererTests: XCTestCase {
    @MainActor
    func testMetalRendererInitialization() {
        let device = MTLCreateSystemDefaultDevice()!
        let renderer = MetalRenderer(device: device)
        XCTAssertNotNil(renderer)
    }
}
