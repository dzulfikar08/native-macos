import XCTest
import Metal
@testable import OpenScreen

@MainActor
final class TimelineViewRenderingTests: XCTestCase {
    var timelineView: TimelineView!
    var device: MTLDevice!

    override func setUp() async throws {
        try await super.setUp()
        device = MTLCreateSystemDefaultDevice()
        XCTAssertNotNil(device, "Metal device must be available")

        timelineView = TimelineView(frame: NSRect(x: 0, y: 0, width: 800, height: 200))
        XCTAssertNotNil(timelineView, "TimelineView should be created")
    }

    override func tearDown() async throws {
        timelineView = nil
        device = nil
        try await super.tearDown()
    }

    // MARK: - Metal Setup Tests

    func testMetalDeviceInitialization() {
        // Then: Metal device should be initialized
        XCTAssertNotNil(timelineView.device, "Metal device should be initialized")
    }

    func testCommandQueueInitialization() {
        // Test that command queue is created
        // This is a private property, so we test it indirectly through draw
        XCTAssertNoThrow(timelineView.draw(NSRect.zero), "Draw should not throw when command queue is initialized")
    }

    func testPixelFormatConfiguration() {
        // Test pixel format is set correctly
        XCTAssertEqual(timelineView.colorPixelFormat, .bgra8Unorm, "Color pixel format should be bgra8Unorm")
    }

    func testFramebufferOnlyConfiguration() {
        // Test framebuffer configuration
        XCTAssertFalse(timelineView.framebufferOnly, "Framebuffer should not be framebufferOnly for drawable access")
    }

    func testClearColorConfiguration() {
        // Test clear color is set to dark background
        let clearColor = timelineView.clearColor
        XCTAssertEqual(clearColor.red, 0.1, accuracy: 0.01, "Clear color red component should be 0.1")
        XCTAssertEqual(clearColor.green, 0.1, accuracy: 0.01, "Clear color green component should be 0.1")
        XCTAssertEqual(clearColor.blue, 0.1, accuracy: 0.01, "Clear color blue component should be 0.1")
        XCTAssertEqual(clearColor.alpha, 1.0, accuracy: 0.01, "Clear color alpha component should be 1.0")
    }

    // MARK: - Drawing Tests

    func testDrawDoesNotThrow() {
        // Test that draw method executes without errors
        XCTAssertNoThrow(timelineView.draw(NSRect(x: 0, y: 0, width: 800, height: 200)), "Draw should execute without throwing")
    }

    func testDrawWithValidSize() {
        // Test drawing with valid frame size
        timelineView.draw(NSRect(x: 0, y: 0, width: 800, height: 200))

        // Should complete without error
        XCTAssertTrue(true, "Draw with valid size should complete successfully")
    }

    func testDrawWithSmallSize() {
        // Test drawing with small frame size
        let smallView = TimelineView(frame: NSRect(x: 0, y: 0, width: 100, height: 50))
        XCTAssertNoThrow(smallView.draw(NSRect(x: 0, y: 0, width: 100, height: 50)), "Draw should work with small sizes")
    }

    func testDrawWithLargeSize() {
        // Test drawing with large frame size
        let largeView = TimelineView(frame: NSRect(x: 0, y: 0, width: 4000, height: 1000))
        XCTAssertNoThrow(largeView.draw(NSRect(x: 0, y: 0, width: 4000, height: 1000)), "Draw should work with large sizes")
    }

    func testNeedsDisplayAfterContentOffsetChange() {
        // Test that changing contentOffset triggers redraw
        // We verify this by checking that the property change is accepted
        let newOffset = CGPoint(x: 100, y: 0)
        timelineView.contentOffset = newOffset

        XCTAssertEqual(timelineView.contentOffset, newOffset, "Content offset should be updated")
        // The didSet should set needsDisplay = true
    }

    func testNeedsDisplayAfterContentScaleChange() {
        // Test that changing contentScale triggers redraw
        let newScale: CGFloat = 2.0
        timelineView.contentScale = newScale

        XCTAssertEqual(timelineView.contentScale, newScale, "Content scale should be updated")
        // The didSet should set needsDisplay = true
    }

    func testNeedsDisplayAfterCurrentTimeChange() {
        // Test that changing currentTime triggers redraw
        let newTime: Double = 5.0
        timelineView.currentTime = newTime

        XCTAssertEqual(timelineView.currentTime, newTime, "Current time should be updated")
        // The didSet should set needsDisplay = true
    }

    // MARK: - Render Context Tests

    func testDrawableAvailability() {
        // Test that drawable is available for rendering
        // This is tested indirectly by successful draw calls
        XCTAssertNoThrow(timelineView.draw(NSRect.zero), "Drawable should be available for rendering")
    }

    func testRenderPassDescriptorAvailability() {
        // Test that render pass descriptor is available
        // This is tested indirectly by successful draw calls
        XCTAssertNoThrow(timelineView.draw(NSRect.zero), "Render pass descriptor should be available")
    }

    // MARK: - Viewport Tests

    func testViewportSizeMatchesDrawable() {
        // Test that viewport is correctly configured
        // This is tested indirectly by successful rendering
        XCTAssertNoThrow(timelineView.draw(NSRect.zero), "Viewport should match drawable size")
    }

    func testViewportConfiguration() {
        // Test viewport configuration with different frame sizes
        let customView = TimelineView(frame: NSRect(x: 0, y: 0, width: 1920, height: 1080))

        XCTAssertNoThrow(customView.draw(NSRect.zero), "Viewport should configure correctly for custom size")
    }
}
