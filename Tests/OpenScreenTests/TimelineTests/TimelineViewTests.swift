import XCTest
import Metal
@testable import OpenScreen

@MainActor
final class TimelineViewTests: XCTestCase {
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

    func testInitialization() {
        // Test basic initialization
        XCTAssertNotNil(timelineView.device, "Metal device should be initialized")
        XCTAssertNotNil(timelineView.layer, "Layer should be initialized")
        XCTAssertEqual(timelineView.frame.size.width, 800)
        XCTAssertEqual(timelineView.frame.size.height, 200)
    }

    func testDefaultValues() {
        // Test default state values
        XCTAssertEqual(timelineView.contentOffset, .zero)
        XCTAssertEqual(timelineView.contentScale, 1.0)
        XCTAssertEqual(timelineView.currentTime, 0.0)
    }

    func testContentOffset() {
        // Test setting content offset
        let newOffset = CGPoint(x: 100, y: 0)
        timelineView.contentOffset = newOffset

        XCTAssertEqual(timelineView.contentOffset, newOffset)
    }

    func testContentScale() {
        // Test setting content scale
        let newScale: CGFloat = 2.0
        timelineView.contentScale = newScale

        XCTAssertEqual(timelineView.contentScale, newScale)
    }

    func testCurrentTime() {
        // Test setting current time
        let newTime: Double = 5.0
        timelineView.currentTime = newTime

        XCTAssertEqual(timelineView.currentTime, newTime)
    }
}
