import XCTest
@testable import OpenScreen

@MainActor
final class LoopRegionViewTests: XCTestCase {

    var loopRegionView: LoopRegionView!
    var mockEditorState: EditorState!

    override func setUp() async throws {
        try await super.setUp()

        // Create a test editor state
        mockEditorState = EditorState.createTestState()

        // Create loop region view
        loopRegionView = LoopRegionView()
        loopRegionView.videoDuration = CMTime(seconds: 60.0, preferredTimescale: 600)
        loopRegionView.delegate = mockEditorState
    }

    override func tearDown() async throws {
        loopRegionView = nil
        mockEditorState = nil
        try await super.tearDown()
    }

    func testInitialization() {
        XCTAssertNotNil(loopRegionView)
        XCTAssertEqual(loopRegionView.loopRegions.count, 0)
        XCTAssertEqual(loopRegionView.videoDuration, CMTime(seconds: 60.0, preferredTimescale: 600))
    }

    func testAddLoopRegion() {
        let loopRegion = createTestLoopRegion()
        loopRegionView.addLoopRegion(loopRegion)

        XCTAssertEqual(loopRegionView.loopRegions.count, 1)
        XCTAssertEqual(loopRegionView.loopRegions.first?.id, loopRegion.id)
    }

    func testRemoveLoopRegion() {
        let loopRegion = createTestLoopRegion()
        loopRegionView.addLoopRegion(loopRegion)

        XCTAssertEqual(loopRegionView.loopRegions.count, 1)

        loopRegionView.removeLoopRegion(loopRegion.id)
        XCTAssertEqual(loopRegionView.loopRegions.count, 0)
    }

    func testUpdateLoopRegion() {
        var loopRegion = createTestLoopRegion()
        loopRegion = LoopRegion(
            id: loopRegion.id,
            name: "Updated Loop",
            timeRange: CMTime(seconds: 20.0, preferredTimescale: 600)...CMTime(seconds: 30.0, preferredTimescale: 600),
            color: .green,
            isActive: true
        )

        loopRegionView.addLoopRegion(loopRegion)

        // Update the region
        loopRegionView.updateLoopRegion(loopRegion)

        XCTAssertEqual(loopRegionView.loopRegions.count, 1)
        XCTAssertEqual(loopRegionView.loopRegions.first?.name, "Updated Loop")
        XCTAssertEqual(loopRegionView.loopRegions.first?.isActive, true)
    }

    func testClearLoopRegions() {
        let loopRegion1 = createTestLoopRegion(name: "Loop 1")
        let loopRegion2 = createTestLoopRegion(name: "Loop 2", start: 20, end: 30)

        loopRegionView.addLoopRegion(loopRegion1)
        loopRegionView.addLoopRegion(loopRegion2)

        XCTAssertEqual(loopRegionView.loopRegions.count, 2)

        loopRegionView.clearLoopRegions()
        XCTAssertEqual(loopRegionView.loopRegions.count, 0)
    }

    func testLoopRegionToXPositionConversion() {
        let loopRegion = createTestLoopRegion(start: 10, end: 20)
        loopRegionView.addLoopRegion(loopRegion)

        let startX = loopRegionView.timeToXPosition(loopRegion.timeRange.lowerBound)
        let endX = loopRegionView.timeToXPosition(loopRegion.timeRange.upperBound)

        XCTAssert(startX < endX)
    }

    func testVisibleRegionCulling() {
        // Add many loop regions
        for i in 0..<10 {
            let loopRegion = createTestLoopRegion(start: Double(i * 10), end: Double(i * 10 + 5))
            loopRegionView.addLoopRegion(loopRegion)
        }

        // Set visible range to show only middle regions
        loopRegionView.visibleTimeRange = CMTime(seconds: 20.0, preferredTimescale: 600)...CMTime(seconds: 50.0, preferredTimescale: 600)

        // Should only render regions within visible range
        XCTAssertEqual(loopRegionView.visibleLoopRegions.count, 3)
    }

    func testResizeHandleHitDetection() {
        let loopRegion = createTestLoopRegion(start: 10, end: 20)
        loopRegionView.addLoopRegion(loopRegion)

        // Test start handle hit
        let startHandleX = loopRegionView.timeToXPosition(loopRegion.timeRange.lowerBound)
        XCTAssertTrue(loopRegionView.isPointInResizeHandle(startHandleX, handleType: .start))

        // Test end handle hit
        let endHandleX = loopRegionView.timeToXPosition(loopRegion.timeRange.upperBound)
        XCTAssertTrue(loopRegionView.isPointInResizeHandle(endHandleX, handleType: .end))

        // Test outside handle
        let outsideX = startHandleX - 20
        XCTAssertFalse(loopRegionView.isPointInResizeHandle(outsideX, handleType: .start))
    }

    // MARK: - Helper Methods

    private func createTestLoopRegion(name: String = "Test Loop", start: Double = 0, end: Double = 10) -> LoopRegion {
        return LoopRegion(
            id: UUID(),
            name: name,
            timeRange: CMTime(seconds: start, preferredTimescale: 600)...CMTime(seconds: end, preferredTimescale: 600),
            color: .blue,
            isActive: false
        )
    }
}