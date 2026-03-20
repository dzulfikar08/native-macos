import XCTest
@testable import OpenScreen
import AVFoundation
import CoreMedia

@MainActor
final class TrimClipOperationTests: XCTestCase {
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

    func testExecuteTrimsClip() throws {
        // Arrange: Trim clip from 10s to 5s
        let newRange = CMTimeRange(
            start: .zero,
            duration: CMTime(seconds: 5.0, preferredTimescale: 600)
        )
        let operation = TrimClipOperation(
            clipID: testClip.id,
            newRange: newRange,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Execute the operation
        try operation.execute()

        // Assert: Clip duration is now 5 seconds
        let clip = track.clips.first { $0.id == testClip.id }
        XCTAssertNotNil(clip, "Clip should still exist")

        XCTAssertEqual(CMTimeGetSeconds(clip!.timeRangeInTimeline.duration), 5.0, accuracy: 0.01)
        XCTAssertEqual(CMTimeGetSeconds(clip!.timeRangeInSource.duration), 5.0, accuracy: 0.01)

        // Assert: Clip still has same ID and track
        XCTAssertEqual(clip!.id, testClip.id)
        XCTAssertEqual(clip!.trackID, track.id)
    }

    // MARK: - Test Undo

    func testUndoRestoresOriginalRange() throws {
        // Arrange: Trim clip and then undo
        let originalDuration = CMTimeGetSeconds(testClip.timeRangeInTimeline.duration)

        let newRange = CMTimeRange(
            start: .zero,
            duration: CMTime(seconds: 5.0, preferredTimescale: 600)
        )
        let operation = TrimClipOperation(
            clipID: testClip.id,
            newRange: newRange,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Execute the trim
        try operation.execute()

        // Verify trim occurred
        XCTAssertEqual(CMTimeGetSeconds(testClip.timeRangeInTimeline.duration), 5.0, accuracy: 0.01)

        // Act: Undo the operation
        try operation.undo()

        // Assert: Original duration is restored
        let clip = track.clips.first { $0.id == testClip.id }
        XCTAssertNotNil(clip, "Clip should still exist")

        XCTAssertEqual(CMTimeGetSeconds(clip!.timeRangeInTimeline.duration), originalDuration, accuracy: 0.01)
        XCTAssertEqual(CMTimeGetSeconds(clip!.timeRangeInSource.duration), originalDuration, accuracy: 0.01)

        // Assert: Original start times are preserved
        XCTAssertEqual(clip!.timeRangeInTimeline.start, testClip.timeRangeInTimeline.start)
        XCTAssertEqual(clip!.timeRangeInSource.start, testClip.timeRangeInSource.start)
    }

    // MARK: - Test Redo

    func testRedoReappliesTrim() throws {
        // Arrange: Trim, undo, then redo
        let newRange = CMTimeRange(
            start: .zero,
            duration: CMTime(seconds: 5.0, preferredTimescale: 600)
        )
        let operation = TrimClipOperation(
            clipID: testClip.id,
            newRange: newRange,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Execute the trim
        try operation.execute()

        // Act: Undo the trim
        try operation.undo()

        // Verify undo worked
        XCTAssertEqual(CMTimeGetSeconds(testClip.timeRangeInTimeline.duration), 10.0, accuracy: 0.01)

        // Act: Redo the trim
        try operation.redo()

        // Assert: Clip is trimmed again
        let clip = track.clips.first { $0.id == testClip.id }
        XCTAssertNotNil(clip, "Clip should still exist")

        XCTAssertEqual(CMTimeGetSeconds(clip!.timeRangeInTimeline.duration), 5.0, accuracy: 0.01)
        XCTAssertEqual(CMTimeGetSeconds(clip!.timeRangeInSource.duration), 5.0, accuracy: 0.01)
    }

    // MARK: - Test Description

    func testDescriptionShowsDurationChange() throws {
        // Arrange: Create operation that trims from 10s to 5s
        let newRange = CMTimeRange(
            start: .zero,
            duration: CMTime(seconds: 5.0, preferredTimescale: 600)
        )
        let operation = TrimClipOperation(
            clipID: testClip.id,
            newRange: newRange,
            editorState: editorState,
            clipManager: clipManager
        )

        // Assert: Description includes clip name and duration change
        XCTAssertTrue(operation.description.contains("Trim Clip"), "Description should mention 'Trim Clip'")
        XCTAssertTrue(operation.description.contains("Test Clip"), "Description should include clip name")
        XCTAssertTrue(operation.description.contains("10"), "Description should include original duration")
        XCTAssertTrue(operation.description.contains("5"), "Description should include new duration")
    }

    // MARK: - Edge Cases

    func testTrimWithNonZeroStart() throws {
        // Arrange: Trim clip starting at 2 seconds in timeline
        let newRange = CMTimeRange(
            start: CMTime(seconds: 2.0, preferredTimescale: 600),
            duration: CMTime(seconds: 5.0, preferredTimescale: 600)
        )
        let operation = TrimClipOperation(
            clipID: testClip.id,
            newRange: newRange,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Execute the trim
        try operation.execute()

        // Assert: Clip has new start time and duration
        let clip = track.clips.first { $0.id == testClip.id }
        XCTAssertNotNil(clip)

        XCTAssertEqual(CMTimeGetSeconds(clip!.timeRangeInTimeline.start), 2.0, accuracy: 0.01)
        XCTAssertEqual(CMTimeGetSeconds(clip!.timeRangeInTimeline.duration), 5.0, accuracy: 0.01)

        // Act: Undo and verify restoration
        try operation.undo()

        let restoredClip = track.clips.first { $0.id == testClip.id }
        XCTAssertEqual(CMTimeGetSeconds(restoredClip!.timeRangeInTimeline.start), 0.0, accuracy: 0.01)
        XCTAssertEqual(CMTimeGetSeconds(restoredClip!.timeRangeInTimeline.duration), 10.0, accuracy: 0.01)
    }

    func testUndoMaintainsClipProperties() throws {
        // Arrange: Create clip with custom properties
        let customClip = TestDataFactory.makeTestVideoClip(
            name: "Custom Clip",
            speed: 2.0,
            sourceDuration: 8,
            timelineStart: CMTime(seconds: 2, preferredTimescale: 600)
        )
        customClip.trackID = track.id
        track.clips.removeAll()
        track.addClip(customClip)

        let newRange = CMTimeRange(
            start: CMTime(seconds: 2.0, preferredTimescale: 600),
            duration: CMTime(seconds: 4.0, preferredTimescale: 600)
        )
        let operation = TrimClipOperation(
            clipID: customClip.id,
            newRange: newRange,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Execute and undo
        try operation.execute()
        try operation.undo()

        // Assert: All clip properties are preserved
        let restoredClip = track.clips.first
        XCTAssertNotNil(restoredClip)

        XCTAssertEqual(restoredClip!.name, "Custom Clip")
        XCTAssertEqual(restoredClip!.speed, 2.0)
        XCTAssertEqual(CMTimeGetSeconds(restoredClip!.timeRangeInTimeline.start), 2.0, accuracy: 0.01)
        XCTAssertEqual(CMTimeGetSeconds(restoredClip!.timeRangeInTimeline.duration), 8.0, accuracy: 0.01)
    }

    func testExecuteThrowsOnInvalidRange() throws {
        // Arrange: Try to trim to duration longer than source
        let invalidRange = CMTimeRange(
            start: .zero,
            duration: CMTime(seconds: 20.0, preferredTimescale: 600) // Clip is only 10 seconds
        )
        let operation = TrimClipOperation(
            clipID: testClip.id,
            newRange: invalidRange,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act & Assert: Should throw error
        XCTAssertThrowsError(try operation.execute()) { error in
            XCTAssertTrue(error is ClipError, "Should throw ClipError")
            if let clipError = error as? ClipError {
                XCTAssertEqual(clipError, .trimExceedsSource, "Should be trimExceedsSource error")
            }
        }
    }

    func testMultipleSequentialTrims() throws {
        // Arrange: Trim clip, then trim it again
        let firstRange = CMTimeRange(
            start: .zero,
            duration: CMTime(seconds: 7.0, preferredTimescale: 600)
        )
        let firstOperation = TrimClipOperation(
            clipID: testClip.id,
            newRange: firstRange,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: First trim (10s -> 7s)
        try firstOperation.execute()
        XCTAssertEqual(CMTimeGetSeconds(testClip.timeRangeInTimeline.duration), 7.0, accuracy: 0.01)

        // Arrange second trim (7s -> 4s)
        let secondRange = CMTimeRange(
            start: .zero,
            duration: CMTime(seconds: 4.0, preferredTimescale: 600)
        )
        let secondOperation = TrimClipOperation(
            clipID: testClip.id,
            newRange: secondRange,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Second trim
        try secondOperation.execute()

        // Assert: Clip is now 4 seconds
        XCTAssertEqual(CMTimeGetSeconds(testClip.timeRangeInTimeline.duration), 4.0, accuracy: 0.01)

        // Act: Undo second trim
        try secondOperation.undo()

        // Assert: Back to 7 seconds
        XCTAssertEqual(CMTimeGetSeconds(testClip.timeRangeInTimeline.duration), 7.0, accuracy: 0.01)

        // Act: Undo first trim
        try firstOperation.undo()

        // Assert: Back to 10 seconds
        XCTAssertEqual(CMTimeGetSeconds(testClip.timeRangeInTimeline.duration), 10.0, accuracy: 0.01)
    }
}
