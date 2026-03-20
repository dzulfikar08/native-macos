import XCTest
@testable import OpenScreen
import AVFoundation
import CoreMedia

@MainActor
final class ClipManagerTests: XCTestCase {
    var editorState: EditorState!
    var clipManager: ClipManager!
    var testTrack: ClipTrack!

    override func setUp() {
        super.setUp()
        editorState = EditorState.createTestState()
        clipManager = ClipManager(editorState: editorState)
        testTrack = ClipTrack(name: "Test Track", type: .video, zIndex: 0)
        editorState.clipTracks.append(testTrack)
    }

    override func tearDown() {
        editorState = nil
        clipManager = nil
        testTrack = nil
        super.tearDown()
    }

    // MARK: - Find Operations (4 tests)

    func testFindClip() {
        let clip = TestDataFactory.makeTestVideoClip(name: "Test Clip")
        testTrack.addClip(clip)

        let foundClip = clipManager.findClip(id: clip.id)

        XCTAssertNotNil(foundClip)
        XCTAssertEqual(foundClip?.id, clip.id)
        XCTAssertEqual(foundClip?.name, "Test Clip")
    }

    func testFindClipNotFound() {
        let randomID = UUID()
        let foundClip = clipManager.findClip(id: randomID)

        XCTAssertNil(foundClip)
    }

    func testFindTrack() {
        let foundTrack = clipManager.findTrack(id: testTrack.id)

        XCTAssertNotNil(foundTrack)
        XCTAssertEqual(foundTrack?.id, testTrack.id)
        XCTAssertEqual(foundTrack?.name, "Test Track")
    }

    func testFindTrackNotFound() {
        let randomID = UUID()
        let foundTrack = clipManager.findTrack(id: randomID)

        XCTAssertNil(foundTrack)
    }

    // MARK: - Split Clip (3 tests)

    func testSplitClipCreatesTwoClips() throws {
        let clip = TestDataFactory.makeTestVideoClip(
            name: "Original",
            sourceDuration: 10,
            timelineStart: .zero
        )
        testTrack.addClip(clip)

        let splitTime = CMTime(seconds: 4, preferredTimescale: 600)
        try clipManager.splitClip(clipID: clip.id, at: splitTime)

        XCTAssertEqual(testTrack.clips.count, 2)

        let leftClip = testTrack.clips.first
        let rightClip = testTrack.clips.last

        // Verify left clip
        XCTAssertEqual(leftClip?.name, "Original (L)")
        XCTAssertEqual(CMTimeGetSeconds(leftClip?.timeRangeInTimeline.duration ?? .zero), 4, accuracy: 0.01)
        XCTAssertEqual(CMTimeGetSeconds(leftClip?.timeRangeInSource.duration ?? .zero), 4, accuracy: 0.01)

        // Verify right clip
        XCTAssertEqual(rightClip?.name, "Original (R)")
        XCTAssertEqual(CMTimeGetSeconds(rightClip?.timeRangeInTimeline.start ?? .zero), 4, accuracy: 0.01)
        XCTAssertEqual(CMTimeGetSeconds(rightClip?.timeRangeInTimeline.duration ?? .zero), 6, accuracy: 0.01)
        XCTAssertEqual(CMTimeGetSeconds(rightClip?.timeRangeInSource.duration ?? .zero), 6, accuracy: 0.01)

        // Verify original clip is removed
        XCTAssertFalse(testTrack.clips.contains(where: { $0.id == clip.id }))
    }

    func testSplitClipAtBoundaryThrows() throws {
        let clip = TestDataFactory.makeTestVideoClip(
            sourceDuration: 10,
            timelineStart: .zero
        )
        testTrack.addClip(clip)

        // Try to split at the start (boundary)
        XCTAssertThrowsError(
            try clipManager.splitClip(clipID: clip.id, at: .zero)
        ) { error in
            guard case ClipError.invalidSplitPoint = error else {
                XCTFail("Expected ClipError.invalidSplitPoint, got \(error)")
                return
            }
        }

        // Try to split at the end (boundary)
        let endTime = clip.timeRangeInTimeline.end
        XCTAssertThrowsError(
            try clipManager.splitClip(clipID: clip.id, at: endTime)
        ) { error in
            guard case ClipError.invalidSplitPoint = error else {
                XCTFail("Expected ClipError.invalidSplitPoint, got \(error)")
                return
            }
        }
    }

    func testSplitClipNotFoundThrows() throws {
        let randomID = UUID()
        let splitTime = CMTime(seconds: 5, preferredTimescale: 600)

        XCTAssertThrowsError(
            try clipManager.splitClip(clipID: randomID, at: splitTime)
        ) { error in
            guard case ClipError.clipNotFound = error else {
                XCTFail("Expected ClipError.clipNotFound, got \(error)")
                return
            }
        }
    }

    // MARK: - Trim Clip (2 tests)

    func testTrimClipUpdatesTimeRange() throws {
        let clip = TestDataFactory.makeTestVideoClip(
            sourceDuration: 10,
            timelineStart: .zero
        )
        testTrack.addClip(clip)

        let newRange = CMTimeRange(
            start: .zero,
            end: CMTime(seconds: 7, preferredTimescale: 600)
        )

        try clipManager.trimClip(clipID: clip.id, to: newRange)

        XCTAssertEqual(
            CMTimeGetSeconds(clip.timeRangeInTimeline.duration),
            7,
            accuracy: 0.01
        )
        XCTAssertEqual(
            CMTimeGetSeconds(clip.timeRangeInSource.duration),
            7,
            accuracy: 0.01
        )
    }

    func testTrimClipNotFoundThrows() throws {
        let randomID = UUID()
        let newRange = CMTimeRange(
            start: .zero,
            end: CMTime(seconds: 5, preferredTimescale: 600)
        )

        XCTAssertThrowsError(
            try clipManager.trimClip(clipID: randomID, to: newRange)
        ) { error in
            guard case ClipError.clipNotFound = error else {
                XCTFail("Expected ClipError.clipNotFound, got \(error)")
                return
            }
        }
    }

    // MARK: - Move Clip (2 tests)

    func testMoveClipToNewPosition() throws {
        let track1 = ClipTrack(name: "Track 1", type: .video, zIndex: 0)
        let track2 = ClipTrack(name: "Track 2", type: .video, zIndex: 1)
        editorState.clipTracks = [track1, track2]

        let clip = TestDataFactory.makeTestVideoClip(
            sourceDuration: 5,
            timelineStart: .zero
        )
        track1.addClip(clip)

        let newRange = CMTimeRange(
            start: CMTime(seconds: 10, preferredTimescale: 600),
            end: CMTime(seconds: 15, preferredTimescale: 600)
        )

        try clipManager.moveClip(clipID: clip.id, to: newRange, on: track2.id, ripple: false)

        // Verify clip is removed from old track
        XCTAssertFalse(track1.clips.contains(where: { $0.id == clip.id }))

        // Verify clip is on new track
        XCTAssertTrue(track2.clips.contains(where: { $0.id == clip.id }))
        XCTAssertEqual(clip.trackID, track2.id)

        // Verify new position
        XCTAssertEqual(CMTimeGetSeconds(clip.timeRangeInTimeline.start), 10, accuracy: 0.01)
    }

    func testMoveClipWithOverlapThrows() throws {
        let clip1 = TestDataFactory.makeTestVideoClip(
            name: "Clip 1",
            sourceDuration: 5,
            timelineStart: .zero
        )
        let clip2 = TestDataFactory.makeTestVideoClip(
            name: "Clip 2",
            sourceDuration: 5,
            timelineStart: CMTime(seconds: 10, preferredTimescale: 600)
        )
        testTrack.addClip(clip1)
        testTrack.addClip(clip2)

        // Try to move clip2 to overlap with clip1
        let newRange = CMTimeRange(
            start: CMTime(seconds: 3, preferredTimescale: 600),
            end: CMTime(seconds: 8, preferredTimescale: 600)
        )

        XCTAssertThrowsError(
            try clipManager.moveClip(clipID: clip2.id, to: newRange, on: testTrack.id, ripple: false)
        ) { error in
            guard case ClipError.wouldOverlap = error else {
                XCTFail("Expected ClipError.wouldOverlap, got \(error)")
                return
            }
        }
    }

    // MARK: - Delete Clip (2 tests)

    func testDeleteClipRemovesFromTrack() throws {
        let clip = TestDataFactory.makeTestVideoClip()
        testTrack.addClip(clip)

        XCTAssertEqual(testTrack.clips.count, 1)

        try clipManager.deleteClip(clipID: clip.id, ripple: false)

        XCTAssertTrue(testTrack.clips.isEmpty)
    }

    func testDeleteClipNotFoundThrows() throws {
        let randomID = UUID()

        XCTAssertThrowsError(
            try clipManager.deleteClip(clipID: randomID, ripple: false)
        ) { error in
            guard case ClipError.clipNotFound = error else {
                XCTFail("Expected ClipError.clipNotFound, got \(error)")
                return
            }
        }
    }

    // MARK: - Duplicate Clip (2 tests)

    func testDuplicateClipCreatesNewClip() throws {
        let clip = TestDataFactory.makeTestVideoClip(
            name: "Original",
            sourceDuration: 5,
            timelineStart: .zero
        )
        testTrack.addClip(clip)

        let newRange = CMTimeRange(
            start: CMTime(seconds: 10, preferredTimescale: 600),
            end: CMTime(seconds: 15, preferredTimescale: 600)
        )

        try clipManager.duplicateClip(clipID: clip.id, to: newRange)

        XCTAssertEqual(testTrack.clips.count, 2)

        let originalClip = testTrack.clips.first
        let duplicateClip = testTrack.clips.last

        // Verify original still exists
        XCTAssertEqual(originalClip?.id, clip.id)
        XCTAssertEqual(originalClip?.name, "Original")

        // Verify duplicate was created
        XCTAssertNotEqual(duplicateClip?.id, clip.id)
        XCTAssertEqual(duplicateClip?.name, "Original copy")
        XCTAssertEqual(CMTimeGetSeconds(duplicateClip?.timeRangeInTimeline.start ?? .zero), 10, accuracy: 0.01)
    }

    func testDuplicateClipWithOverlapThrows() throws {
        let clip1 = TestDataFactory.makeTestVideoClip(
            name: "Clip 1",
            sourceDuration: 5,
            timelineStart: .zero
        )
        let clip2 = TestDataFactory.makeTestVideoClip(
            name: "Clip 2",
            sourceDuration: 5,
            timelineStart: CMTime(seconds: 10, preferredTimescale: 600)
        )
        testTrack.addClip(clip1)
        testTrack.addClip(clip2)

        // Try to duplicate clip1 to overlap with clip2
        let newRange = CMTimeRange(
            start: CMTime(seconds: 8, preferredTimescale: 600),
            end: CMTime(seconds: 13, preferredTimescale: 600)
        )

        XCTAssertThrowsError(
            try clipManager.duplicateClip(clipID: clip1.id, to: newRange)
        ) { error in
            guard case ClipError.wouldOverlap = error else {
                XCTFail("Expected ClipError.wouldOverlap, got \(error)")
                return
            }
        }
    }

    // MARK: - Change Clip Speed (3 tests)

    func testChangeClipSpeedUpdatesDuration() throws {
        let clip = TestDataFactory.makeTestVideoClip(
            sourceDuration: 10,
            timelineStart: .zero
        )
        testTrack.addClip(clip)

        let originalTimelineDuration = clip.timelineDuration

        // Change speed to 2x
        try clipManager.changeClipSpeed(clipID: clip.id, to: 2.0)

        XCTAssertEqual(clip.speed, 2.0, accuracy: 0.01)

        // Timeline duration should be halved
        let newTimelineDuration = clip.timelineDuration
        XCTAssertEqual(
            CMTimeGetSeconds(newTimelineDuration),
            CMTimeGetSeconds(originalTimelineDuration) / 2.0,
            accuracy: 0.01
        )

        // Timeline timeRange should maintain end point but duration changes
        XCTAssertEqual(CMTimeGetSeconds(clip.timeRangeInTimeline.start), 0, accuracy: 0.01)
        XCTAssertEqual(CMTimeGetSeconds(clip.timeRangeInTimeline.duration), 5, accuracy: 0.01)
    }

    func testChangeClipSpeedPostsNotificationWithCorrectUserInfo() throws {
        let clip = TestDataFactory.makeTestVideoClip(
            sourceDuration: 10,
            timelineStart: .zero
        )
        testTrack.addClip(clip)

        let oldSpeed = clip.speed

        let expectation = XCTestExpectation(description: "Notification posted")
        let observer = NotificationCenter.default.addObserver(
            forName: .clipDidChangeSpeed,
            object: clipManager,
            queue: nil
        ) { notification in
            guard let userInfo = notification.userInfo,
                  let notifiedClip = userInfo["clip"] as? VideoClip,
                  let notifiedOldSpeed = userInfo["oldSpeed"] as? Float else {
                XCTFail("Missing or invalid userInfo in notification")
                return
            }

            XCTAssertEqual(notifiedClip.id, clip.id)
            XCTAssertEqual(notifiedOldSpeed, oldSpeed, accuracy: 0.01)
            expectation.fulfill()
        }

        try clipManager.changeClipSpeed(clipID: clip.id, to: 2.0)

        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }

    func testChangeClipSpeedOutOfRangeThrows() throws {
        let clip = TestDataFactory.makeTestVideoClip()
        testTrack.addClip(clip)

        // Test too slow
        XCTAssertThrowsError(
            try clipManager.changeClipSpeed(clipID: clip.id, to: 0.05)
        ) { error in
            guard case ClipError.invalidSpeed = error else {
                XCTFail("Expected ClipError.invalidSpeed, got \(error)")
                return
            }
        }

        // Test too fast
        XCTAssertThrowsError(
            try clipManager.changeClipSpeed(clipID: clip.id, to: 20.0)
        ) { error in
            guard case ClipError.invalidSpeed = error else {
                XCTFail("Expected ClipError.invalidSpeed, got \(error)")
                return
            }
        }
    }
}
