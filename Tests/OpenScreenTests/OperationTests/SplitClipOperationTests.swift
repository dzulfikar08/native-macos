import XCTest
@testable import OpenScreen
import AVFoundation
import CoreMedia

@MainActor
final class SplitClipOperationTests: XCTestCase {
    var editorState: EditorState!
    var clipManager: ClipManager!
    var track: ClipTrack!
    var testClip: VideoClip!

    override func setUp() {
        super.setUp()
        editorState = EditorState.createTestState()
        clipManager = ClipManager(editorState: editorState)

        // Create a test track
        track = ClipTrack(id: UUID(), name: "Test Track", type: .video)
        editorState.clipTracks.append(track)

        // Create a test clip (10 seconds duration)
        testClip = TestDataFactory.makeTestVideoClip(
            name: "Test Clip",
            sourceDuration: 10,
            timelineStart: .zero
        )
        testClip.trackID = track.id
        track.addClip(testClip)
    }

    override func tearDown() {
        editorState = nil
        clipManager = nil
        track = nil
        testClip = nil
        super.tearDown()
    }

    // MARK: - Test Execute

    func testExecuteSplitsClip() throws {
        // Arrange: Split at 5 seconds
        let splitTime = CMTime(seconds: 5.0, preferredTimescale: 600)
        let operation = SplitClipOperation(
            clipID: testClip.id,
            splitTime: splitTime,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Execute the operation
        try operation.execute()

        // Assert: Original clip is removed
        XCTAssertNil(track.clips.first { $0.id == testClip.id }, "Original clip should be removed")

        // Assert: Two new clips exist with (L) and (R) suffixes
        let leftClip = track.clips.first { $0.name == "Test Clip (L)" }
        let rightClip = track.clips.first { $0.name == "Test Clip (R)" }

        XCTAssertNotNil(leftClip, "Left clip should exist")
        XCTAssertNotNil(rightClip, "Right clip should exist")

        // Assert: Left clip spans 0-5 seconds
        XCTAssertEqual(leftClip!.timeRangeInTimeline.start, .zero)
        XCTAssertEqual(CMTimeGetSeconds(leftClip!.timeRangeInTimeline.duration), 5.0, accuracy: 0.01)

        // Assert: Right clip spans 5-10 seconds
        XCTAssertEqual(CMTimeGetSeconds(rightClip!.timeRangeInTimeline.start), 5.0, accuracy: 0.01)
        XCTAssertEqual(CMTimeGetSeconds(rightClip!.timeRangeInTimeline.duration), 5.0, accuracy: 0.01)

        // Assert: Both clips share the same asset
        XCTAssertEqual(leftClip!.asset, testClip.asset)
        XCTAssertEqual(rightClip!.asset, testClip.asset)

        // Assert: Both clips are on the same track
        XCTAssertEqual(leftClip!.trackID, track.id)
        XCTAssertEqual(rightClip!.trackID, track.id)
    }

    // MARK: - Test Undo

    func testUndoRestoresOriginalClip() throws {
        // Arrange: Split and then undo
        let splitTime = CMTime(seconds: 5.0, preferredTimescale: 600)
        let operation = SplitClipOperation(
            clipID: testClip.id,
            splitTime: splitTime,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Execute the split
        try operation.execute()

        // Verify split occurred
        XCTAssertEqual(track.clips.count, 2, "Should have 2 clips after split")

        // Act: Undo the operation
        try operation.undo()

        // Assert: Split clips are removed
        XCTAssertNil(track.clips.first { $0.name == "Test Clip (L)" })
        XCTAssertNil(track.clips.first { $0.name == "Test Clip (R)" })

        // Assert: Original clip is restored with same ID
        let restoredClip = track.clips.first { $0.id == testClip.id }
        XCTAssertNotNil(restoredClip, "Original clip should be restored")

        // Assert: Original clip properties are preserved
        XCTAssertEqual(restoredClip!.id, testClip.id)
        XCTAssertEqual(restoredClip!.name, testClip.name)
        XCTAssertEqual(restoredClip!.trackID, testClip.trackID)
        XCTAssertEqual(CMTimeGetSeconds(restoredClip!.timeRangeInTimeline.start),
                       CMTimeGetSeconds(testClip.timeRangeInTimeline.start),
                       accuracy: 0.01)
        XCTAssertEqual(CMTimeGetSeconds(restoredClip!.timeRangeInTimeline.duration),
                       CMTimeGetSeconds(testClip.timeRangeInTimeline.duration),
                       accuracy: 0.01)

        // Assert: Only one clip on track
        XCTAssertEqual(track.clips.count, 1, "Should have 1 clip after undo")
    }

    // MARK: - Test Redo

    func testRedoSplitsAgain() throws {
        // Arrange: Split, undo, then redo
        let splitTime = CMTime(seconds: 5.0, preferredTimescale: 600)
        let operation = SplitClipOperation(
            clipID: testClip.id,
            splitTime: splitTime,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Execute the split
        try operation.execute()

        // Act: Undo the split
        try operation.undo()

        // Verify undo worked
        XCTAssertEqual(track.clips.count, 1, "Should have 1 clip after undo")

        // Act: Redo the split
        try operation.redo()

        // Assert: Split clips are back
        let leftClip = track.clips.first { $0.name == "Test Clip (L)" }
        let rightClip = track.clips.first { $0.name == "Test Clip (R)" }

        XCTAssertNotNil(leftClip, "Left clip should exist after redo")
        XCTAssertNotNil(rightClip, "Right clip should exist after redo")

        // Assert: Original clip is gone again
        XCTAssertNil(track.clips.first { $0.id == testClip.id }, "Original clip should be removed after redo")

        // Assert: Two clips on track
        XCTAssertEqual(track.clips.count, 2, "Should have 2 clips after redo")
    }

    // MARK: - Test Description

    func testDescriptionProvidesContext() throws {
        // Arrange: Create operation with specific split time
        let splitTime = CMTime(seconds: 3.5, preferredTimescale: 600)
        let operation = SplitClipOperation(
            clipID: testClip.id,
            splitTime: splitTime,
            editorState: editorState,
            clipManager: clipManager
        )

        // Assert: Description includes clip name and split time
        XCTAssertTrue(operation.description.contains("Split Clip"), "Description should mention 'Split Clip'")
        XCTAssertTrue(operation.description.contains("Test Clip"), "Description should include clip name")
        XCTAssertTrue(operation.description.contains("3.5"), "Description should include split time")
    }

    // MARK: - Edge Cases

    func testExecuteThrowsOnInvalidSplitPoint() throws {
        // Arrange: Try to split at a point outside the clip
        let invalidSplitTime = CMTime(seconds: 15.0, preferredTimescale: 600) // Clip is only 10 seconds
        let operation = SplitClipOperation(
            clipID: testClip.id,
            splitTime: invalidSplitTime,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act & Assert: Should throw error
        XCTAssertThrowsError(try operation.execute()) { error in
            XCTAssertTrue(error is ClipError, "Should throw ClipError")
            if let clipError = error as? ClipError {
                XCTAssertEqual(clipError, .invalidSplitPoint, "Should be invalidSplitPoint error")
            }
        }
    }

    func testUndoMaintainsClipState() throws {
        // Arrange: Create clip with specific properties
        let customClip = TestDataFactory.makeTestVideoClip(
            name: "Custom Clip",
            speed: 2.0,
            sourceDuration: 8,
            timelineStart: CMTime(seconds: 2, preferredTimescale: 600)
        )
        customClip.trackID = track.id
        track.clips.removeAll()
        track.addClip(customClip)

        let splitTime = CMTime(seconds: 5.0, preferredTimescale: 600)
        let operation = SplitClipOperation(
            clipID: customClip.id,
            splitTime: splitTime,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Execute and undo
        try operation.execute()
        try operation.undo()

        // Assert: All clip properties are restored
        let restoredClip = track.clips.first
        XCTAssertNotNil(restoredClip)

        XCTAssertEqual(restoredClip!.name, "Custom Clip")
        XCTAssertEqual(restoredClip!.speed, 2.0)
        XCTAssertEqual(CMTimeGetSeconds(restoredClip!.timeRangeInTimeline.start), 2.0, accuracy: 0.01)
        XCTAssertEqual(CMTimeGetSeconds(restoredClip!.timeRangeInTimeline.duration), 8.0, accuracy: 0.01)
    }

    func testMultipleSequentialSplits() throws {
        // Arrange: Split clip, then split one of the resulting clips
        let firstSplitTime = CMTime(seconds: 5.0, preferredTimescale: 600)
        let firstOperation = SplitClipOperation(
            clipID: testClip.id,
            splitTime: firstSplitTime,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: First split
        try firstOperation.execute()

        // Get the right clip to split it again
        let rightClip = track.clips.first { $0.name == "Test Clip (R)" }
        XCTAssertNotNil(rightClip)

        // Arrange second split on the right clip (at 7.5 seconds on timeline)
        let secondSplitTime = CMTime(seconds: 7.5, preferredTimescale: 600)
        let secondOperation = SplitClipOperation(
            clipID: rightClip!.id,
            splitTime: secondSplitTime,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Second split
        try secondOperation.execute()

        // Assert: Should have 3 clips now
        XCTAssertEqual(track.clips.count, 3, "Should have 3 clips after two splits")

        // Assert: Original left clip still exists
        let leftClip = track.clips.first { $0.name == "Test Clip (L)" }
        XCTAssertNotNil(leftClip)

        // Assert: Right clip was split into two
        let middleClip = track.clips.first { $0.name == "Test Clip (R) (L)" }
        let rightMostClip = track.clips.first { $0.name == "Test Clip (R) (R)" }
        XCTAssertNotNil(middleClip)
        XCTAssertNotNil(rightMostClip)
    }

    func testUndoOnlyRemovesSplitClips() throws {
        // Arrange: Track with multiple clips, split one of them
        let anotherClip = TestDataFactory.makeTestVideoClip(
            name: "Another Clip",
            sourceDuration: 5,
            timelineStart: CMTime(seconds: 10, preferredTimescale: 600)
        )
        anotherClip.trackID = track.id
        track.addClip(anotherClip)

        let initialClipCount = track.clips.count
        let splitTime = CMTime(seconds: 5.0, preferredTimescale: 600)
        let operation = SplitClipOperation(
            clipID: testClip.id,
            splitTime: splitTime,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Execute and undo
        try operation.execute()
        try operation.undo()

        // Assert: Only the split clip was affected, other clip remains
        XCTAssertEqual(track.clips.count, initialClipCount, "Clip count should be same as initial")
        XCTAssertNotNil(track.clips.first { $0.name == "Another Clip" }, "Other clip should still exist")
        XCTAssertNotNil(track.clips.first { $0.id == testClip.id }, "Original clip should be restored")
    }
}
