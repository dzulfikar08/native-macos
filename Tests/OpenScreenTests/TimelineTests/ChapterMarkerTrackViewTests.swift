import XCTest
import CoreMedia
@testable import OpenScreen

@MainActor
final class ChapterMarkerTrackViewTests: XCTestCase {

    var chapterMarkerTrackView: ChapterMarkerTrackView!
    var mockEditorState: EditorState!

    override func setUp() async throws {
        try await super.setUp()

        // Create a test editor state
        mockEditorState = EditorState.createTestState()

        // Create chapter marker track view
        chapterMarkerTrackView = ChapterMarkerTrackView()
        chapterMarkerTrackView.videoDuration = CMTime(seconds: 60.0, preferredTimescale: 600)
        chapterMarkerTrackView.delegate = mockEditorState
    }

    override func tearDown() async throws {
        chapterMarkerTrackView = nil
        mockEditorState = nil
        try await super.tearDown()
    }

    func testInitialization() {
        XCTAssertNotNil(chapterMarkerTrackView)
        XCTAssertEqual(chapterMarkerTrackView.chapterMarkers.count, 0)
        XCTAssertEqual(chapterMarkerTrackView.videoDuration, CMTime(seconds: 60.0, preferredTimescale: 600))
    }

    func testAddChapterMarker() {
        let chapterMarker = createTestChapterMarker()
        chapterMarkerTrackView.addChapterMarker(chapterMarker)

        XCTAssertEqual(chapterMarkerTrackView.chapterMarkers.count, 1)
        XCTAssertEqual(chapterMarkerTrackView.chapterMarkers.first?.id, chapterMarker.id)
    }

    func testRemoveChapterMarker() {
        let chapterMarker = createTestChapterMarker()
        chapterMarkerTrackView.addChapterMarker(chapterMarker)

        XCTAssertEqual(chapterMarkerTrackView.chapterMarkers.count, 1)

        chapterMarkerTrackView.removeChapterMarker(chapterMarker.id)
        XCTAssertEqual(chapterMarkerTrackView.chapterMarkers.count, 0)
    }

    func testUpdateChapterMarker() {
        var chapterMarker = createTestChapterMarker()
        chapterMarker = ChapterMarker(
            id: chapterMarker.id,
            name: "Updated Chapter",
            time: CMTime(seconds: 30.0, preferredTimescale: 600),
            notes: "Updated notes",
            color: .green
        )

        chapterMarkerTrackView.addChapterMarker(chapterMarker)

        // Update the marker
        chapterMarkerTrackView.updateChapterMarker(chapterMarker)

        XCTAssertEqual(chapterMarkerTrackView.chapterMarkers.count, 1)
        XCTAssertEqual(chapterMarkerTrackView.chapterMarkers.first?.name, "Updated Chapter")
        XCTAssertEqual(chapterMarkerTrackView.chapterMarkers.first?.notes, "Updated notes")
    }

    func testClearChapterMarkers() {
        let marker1 = createTestChapterMarker(name: "Chapter 1")
        let marker2 = createTestChapterMarker(name: "Chapter 2", time: 30)

        chapterMarkerTrackView.addChapterMarker(marker1)
        chapterMarkerTrackView.addChapterMarker(marker2)

        XCTAssertEqual(chapterMarkerTrackView.chapterMarkers.count, 2)

        chapterMarkerTrackView.clearChapterMarkers()
        XCTAssertEqual(chapterMarkerTrackView.chapterMarkers.count, 0)
    }

    func testChapterMarkerToXPositionConversion() {
        let chapterMarker = createTestChapterMarker()
        chapterMarkerTrackView.addChapterMarker(chapterMarker)

        let xPosition = chapterMarkerTrackView.timeToXPosition(chapterMarker.time)

        XCTAssertGreaterThanOrEqual(xPosition, 0)
    }

    func testVisibleMarkerCullingPerformance() {
        // Add many markers (simulating 100+ markers)
        for i in 0..<150 {
            let marker = createTestChapterMarker(name: "Chapter \(i)", time: Double(i))
            chapterMarkerTrackView.addChapterMarker(marker)
        }

        XCTAssertEqual(chapterMarkerTrackView.chapterMarkers.count, 150)

        // Set visible range
        chapterMarkerTrackView.visibleTimeRange = CMTime(seconds: 40.0, preferredTimescale: 600)...CMTime(seconds: 60.0, preferredTimescale: 600)

        // Should only render markers within visible range
        XCTAssertEqual(chapterMarkerTrackView.visibleChapterMarkers.count, 21) // 40, 41, ..., 60

        // Performance should be fast (less than 1ms for culling)
        let startTime = CFAbsoluteTimeGetCurrent()
        _ = chapterMarkerTrackView.visibleChapterMarkers
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime

        XCTAssertLessThanOrEqual(timeElapsed, 0.001, "Marker culling should be fast")
    }

    func testMarkerHitDetection() {
        let chapterMarker = createTestChapterMarker()
        chapterMarkerTrackView.addChapterMarker(chapterMarker)

        let markerX = chapterMarkerTrackView.timeToXPosition(chapterMarker.time)

        // Test hit detection
        XCTAssertTrue(chapterMarkerTrackView.isPointInMarker(markerX))

        // Test miss detection
        let missX = markerX + 50
        XCTAssertFalse(chapterMarkerTrackView.isPointInMarker(missX))
    }

    func testColorCoding() {
        let marker1 = createTestChapterMarker(name: "Chapter 1", color: .blue)
        let marker2 = createTestChapterMarker(name: "Chapter 2", color: .green)
        let marker3 = createTestChapterMarker(name: "Chapter 3", color: .orange)

        chapterMarkerTrackView.addChapterMarker(marker1)
        chapterMarkerTrackView.addChapterMarker(marker2)
        chapterMarkerTrackView.addChapterMarker(marker3)

        XCTAssertEqual(chapterMarkerTrackView.chapterMarkers[0].color, .blue)
        XCTAssertEqual(chapterMarkerTrackView.chapterMarkers[1].color, .green)
        XCTAssertEqual(chapterMarkerTrackView.chapterMarkers[2].color, .orange)
    }

    // MARK: - Helper Methods

    private func createTestChapterMarker(name: String = "Test Chapter", time: Double = 10, color: TimelineColor = .blue) -> ChapterMarker {
        return ChapterMarker(
            id: UUID(),
            name: name,
            time: CMTime(seconds: time, preferredTimescale: 600),
            notes: "Test notes",
            color: color
        )
    }
}