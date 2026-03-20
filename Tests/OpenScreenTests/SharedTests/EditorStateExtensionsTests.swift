import XCTest
import AVFoundation
@testable import OpenScreen

// MARK: - Tests

@MainActor
final class EditorStateExtensionsTests: XCTestCase {
    func testLoopRegionsInitialState() {
        let state = EditorState(assetURL: TestDataFactory.makeTestRecordingURL())
        XCTAssertTrue(state.loopRegions.isEmpty)
        XCTAssertNil(state.activeLoopRegionID)
    }

    func testAddLoopRegion() {
        let state = EditorState(assetURL: TestDataFactory.makeTestRecordingURL())
        let loop = LoopRegion(
            name: "Test Loop",
            timeRange: CMTime(seconds: 0, preferredTimescale: 600)...CMTime(seconds: 10, preferredTimescale: 600),
            color: TimelineColor.blue,
            isActive: true,
            useInOutPoints: false
        )

        state.loopRegions.append(loop)
        state.activeLoopRegionID = loop.id

        XCTAssertEqual(state.loopRegions.count, 1)
        XCTAssertEqual(state.activeLoopRegionID, loop.id)
    }

    func testChapterMarkersInitialState() {
        let state = EditorState(assetURL: TestDataFactory.makeTestRecordingURL())
        XCTAssertTrue(state.chapterMarkers.isEmpty)
    }

    func testAddChapterMarker() {
        let state = EditorState(assetURL: TestDataFactory.makeTestRecordingURL())
        let marker = ChapterMarker(
            name: "Intro",
            time: CMTime(seconds: 5, preferredTimescale: 600),
            notes: "Opening sequence",
            color: TimelineColor.green
        )

        state.chapterMarkers.append(marker)

        XCTAssertEqual(state.chapterMarkers.count, 1)
        XCTAssertEqual(state.chapterMarkers.first?.name, "Intro")
    }

    func testInOutPointsInitialState() {
        let state = EditorState(assetURL: TestDataFactory.makeTestRecordingURL())
        XCTAssertNil(state.inPoint)
        XCTAssertNil(state.outPoint)
        XCTAssertEqual(state.focusMode, .showFullTimeline)
    }

    func testSetInOutPoints() {
        let state = EditorState(assetURL: TestDataFactory.makeTestRecordingURL())
        state.inPoint = CMTime(seconds: 2, preferredTimescale: 600)
        state.outPoint = CMTime(seconds: 8, preferredTimescale: 600)

        XCTAssertEqual(state.inPoint, CMTime(seconds: 2, preferredTimescale: 600))
        XCTAssertEqual(state.outPoint, CMTime(seconds: 8, preferredTimescale: 600))
    }

    func testFocusModeToggle() {
        let state = EditorState(assetURL: TestDataFactory.makeTestRecordingURL())
        XCTAssertEqual(state.focusMode, .showFullTimeline)

        state.focusMode = .focusOnSelection
        XCTAssertEqual(state.focusMode, .focusOnSelection)
    }

    func testScrubbingState() {
        let state = EditorState(assetURL: TestDataFactory.makeTestRecordingURL())
        XCTAssertFalse(state.isScrubbing)

        state.isScrubbing = true
        XCTAssertTrue(state.isScrubbing)
    }

    func testPlaybackRateRange() {
        let state = EditorState(assetURL: TestDataFactory.makeTestRecordingURL())
        // Verify playbackRate can handle -4.0 to 4.0 range
        state.playbackRate = -4.0
        XCTAssertEqual(state.playbackRate, -4.0)

        state.playbackRate = 2.5
        XCTAssertEqual(state.playbackRate, 2.5)
    }

    func testNotificationPostedOnStateChange() {
        let state = EditorState(assetURL: TestDataFactory.makeTestRecordingURL())
        let expectation = XCTestExpectation(description: "Notification posted")

        let observer = NotificationCenter.default.addObserver(
            forName: .loopRegionsDidChange,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }

        state.loopRegions.append(LoopRegion(
            name: "Test",
            timeRange: CMTime(seconds: 0, preferredTimescale: 600)...CMTime(seconds: 5, preferredTimescale: 600),
            color: TimelineColor.blue,
            isActive: false,
            useInOutPoints: false
        ))

        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }

    func testInPointValidationRejectsNegativeTime() {
        let state = EditorState(assetURL: TestDataFactory.makeTestRecordingURL())

        // Attempt to set negative time
        state.inPoint = CMTime(seconds: -1, preferredTimescale: 600)

        // Should be rejected and set to nil
        XCTAssertNil(state.inPoint, "Negative inPoint should be rejected")
    }

    func testOutPointValidationRejectsNegativeTime() {
        let state = EditorState(assetURL: TestDataFactory.makeTestRecordingURL())

        // Attempt to set negative time
        state.outPoint = CMTime(seconds: -1, preferredTimescale: 600)

        // Should be rejected and set to nil
        XCTAssertNil(state.outPoint, "Negative outPoint should be rejected")
    }

    func testInPointNotificationPosted() {
        let state = EditorState(assetURL: TestDataFactory.makeTestRecordingURL())
        let expectation = XCTestExpectation(description: "inPoint notification posted")

        let observer = NotificationCenter.default.addObserver(
            forName: .inPointDidChange,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }

        state.inPoint = CMTime(seconds: 2, preferredTimescale: 600)

        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }

    func testOutPointNotificationPosted() {
        let state = EditorState(assetURL: TestDataFactory.makeTestRecordingURL())
        let expectation = XCTestExpectation(description: "outPoint notification posted")

        let observer = NotificationCenter.default.addObserver(
            forName: .outPointDidChange,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }

        state.outPoint = CMTime(seconds: 8, preferredTimescale: 600)

        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }
}
