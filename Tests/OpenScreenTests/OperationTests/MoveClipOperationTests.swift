import XCTest
@testable import OpenScreen
import AVFoundation
import CoreMedia

@MainActor
final class MoveClipOperationTests: XCTestCase {
    var editorState: EditorState!
    var clipManager: ClipManager!
    var sourceTrack: ClipTrack!
    var targetTrack: ClipTrack!
    var testClip: VideoClip!

    override func setUp() {
        super.setUp()
        editorState = EditorState.createTestState()
        clipManager = ClipManager(editorState: editorState)

        // Create source and target tracks
        sourceTrack = ClipTrack(id: UUID(), name: "Source Track", type: .video)
        targetTrack = ClipTrack(id: UUID(), name: "Target Track", type: .video)
        editorState.clipTracks.append(sourceTrack)
        editorState.clipTracks.append(targetTrack)

        // Create a test clip (10 seconds duration)
        testClip = TestDataFactory.makeTestVideoClip(
            name: "Test Clip",
            sourceDuration: 10,
            timelineStart: .zero
        )
        testClip.trackID = sourceTrack.id
        sourceTrack.addClip(testClip)
    }

    override func tearDown() {
        editorState = nil
        clipManager = nil
        sourceTrack = nil
        targetTrack = nil
        testClip = nil
        super.tearDown()
    }

    // MARK: - Test Execute

    func testExecuteMovesClip() throws {
        // Arrange: Move to different track and position
        let newRange = CMTimeRange(start: CMTime(seconds: 5, preferredTimescale: 600), duration: CMTime(seconds: 10, preferredTimescale: 600))
        let operation = MoveClipOperation(
            clipID: testClip.id,
            newRange: newRange,
            newTrackID: targetTrack.id,
            ripple: false,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Execute the operation
        try operation.execute()

        // Assert: Clip is no longer on source track
        XCTAssertNil(sourceTrack.clips.first { $0.id == testClip.id }, "Clip should not be on source track")

        // Assert: Clip is on target track
        let movedClip = targetTrack.clips.first { $0.id == testClip.id }
        XCTAssertNotNil(movedClip, "Clip should be on target track")

        // Assert: Clip has correct new position
        XCTAssertEqual(movedClip!.timeRangeInTimeline.start, newRange.start)
        XCTAssertEqual(movedClip!.timeRangeInTimeline.duration, newRange.duration)
        XCTAssertEqual(movedClip!.trackID, targetTrack.id)
    }

    func testExecuteMovesWithRipple() throws {
        // Arrange: Add another clip to source track
        let secondClip = TestDataFactory.makeTestVideoClip(
            name: "Second Clip",
            sourceDuration: 5,
            timelineStart: CMTime(seconds: 10, preferredTimescale: 600)
        )
        secondClip.trackID = sourceTrack.id
        sourceTrack.addClip(secondClip)

        // Arrange: Move first clip forward with ripple
        let newRange = CMTimeRange(start: CMTime(seconds: 15, preferredTimescale: 600), duration: CMTime(seconds: 10, preferredTimescale: 600))
        let operation = MoveClipOperation(
            clipID: testClip.id,
            newRange: newRange,
            newTrackID: sourceTrack.id,
            ripple: true,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Execute the operation
        try operation.execute()

        // Assert: First clip moved to new position
        let movedClip = sourceTrack.clips.first { $0.id == testClip.id }
        XCTAssertEqual(movedClip!.timeRangeInTimeline.start, newRange.start)

        // Assert: Second clip shifted forward
        let shiftedClip = sourceTrack.clips.first { $0.id == secondClip.id }
        XCTAssertEqual(shiftedClip!.timeRangeInTimeline.start, CMTime(seconds: 25, preferredTimescale: 600))
    }

    // MARK: - Test Undo

    func testUndoReturnsToOriginalTrack() throws {
        // Arrange: Move clip to different track
        let newRange = CMTimeRange(start: CMTime(seconds: 5, preferredTimescale: 600), duration: CMTime(seconds: 10, preferredTimescale: 600))
        let operation = MoveClipOperation(
            clipID: testClip.id,
            newRange: newRange,
            newTrackID: targetTrack.id,
            ripple: false,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Execute the move
        try operation.execute()

        // Verify move occurred
        XCTAssertNotNil(targetTrack.clips.first { $0.id == testClip.id })
        XCTAssertNil(sourceTrack.clips.first { $0.id == testClip.id })

        // Act: Undo the operation
        try operation.undo()

        // Assert: Clip is back on original track
        XCTAssertNotNil(sourceTrack.clips.first { $0.id == testClip.id }, "Clip should be back on source track")
        XCTAssertNil(targetTrack.clips.first { $0.id == testClip.id }, "Clip should not be on target track")

        // Assert: Clip has original position
        let restoredClip = sourceTrack.clips.first { $0.id == testClip.id }
        XCTAssertEqual(restoredClip!.timeRangeInTimeline.start, .zero)
        XCTAssertEqual(restoredClip!.timeRangeInTimeline.duration, CMTime(seconds: 10, preferredTimescale: 600))
    }

    func testUndoRestoresOriginalPosition() throws {
        // Arrange: Move clip to different position on same track
        let newRange = CMTimeRange(start: CMTime(seconds: 5, preferredTimescale: 600), duration: CMTime(seconds: 10, preferredTimescale: 600))
        let operation = MoveClipOperation(
            clipID: testClip.id,
            newRange: newRange,
            newTrackID: sourceTrack.id,
            ripple: false,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Execute and undo
        try operation.execute()
        try operation.undo()

        // Assert: Clip is back at original position
        let restoredClip = sourceTrack.clips.first { $0.id == testClip.id }
        XCTAssertNotNil(restoredClip)
        XCTAssertEqual(restoredClip!.timeRangeInTimeline.start, .zero)
        XCTAssertEqual(CMTimeGetSeconds(restoredClip!.timeRangeInTimeline.duration), 10.0, accuracy: 0.01)
    }

    func testUndoWithoutAffectsOtherClips() throws {
        // Arrange: Add another clip to track
        let secondClip = TestDataFactory.makeTestVideoClip(
            name: "Second Clip",
            sourceDuration: 5,
            timelineStart: CMTime(seconds: 10, preferredTimescale: 600)
        )
        secondClip.trackID = sourceTrack.id
        sourceTrack.addClip(secondClip)

        // Arrange: Move first clip without ripple
        let newRange = CMTimeRange(start: CMTime(seconds: 20, preferredTimescale: 600), duration: CMTime(seconds: 10, preferredTimescale: 600))
        let operation = MoveClipOperation(
            clipID: testClip.id,
            newRange: newRange,
            newTrackID: targetTrack.id,
            ripple: false,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Execute and undo
        try operation.execute()
        try operation.undo()

        // Assert: Second clip position unchanged
        XCTAssertNotNil(sourceTrack.clips.first { $0.name == "Second Clip" })
        let secondClipAfter = sourceTrack.clips.first { $0.name == "Second Clip" }
        XCTAssertEqual(secondClipAfter!.timeRangeInTimeline.start, CMTime(seconds: 10, preferredTimescale: 600))
    }

    // MARK: - Test Redo

    func testRedoMovesAgain() throws {
        // Arrange: Move, undo, then redo
        let newRange = CMTimeRange(start: CMTime(seconds: 5, preferredTimescale: 600), duration: CMTime(seconds: 10, preferredTimescale: 600))
        let operation = MoveClipOperation(
            clipID: testClip.id,
            newRange: newRange,
            newTrackID: targetTrack.id,
            ripple: false,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Execute, undo, then redo
        try operation.execute()
        try operation.undo()
        try operation.redo()

        // Assert: Clip is back on target track
        XCTAssertNotNil(targetTrack.clips.first { $0.id == testClip.id }, "Clip should be on target track after redo")
        XCTAssertNil(sourceTrack.clips.first { $0.id == testClip.id }, "Clip should not be on source track after redo")

        // Assert: Clip has new position
        let movedClip = targetTrack.clips.first { $0.id == testClip.id }
        XCTAssertEqual(movedClip!.timeRangeInTimeline.start, newRange.start)
        XCTAssertEqual(movedClip!.timeRangeInTimeline.duration, newRange.duration)
    }

    func testRedoWithRippleAgain() throws {
        // Arrange: Add another clip to source track
        let secondClip = TestDataFactory.makeTestVideoClip(
            name: "Second Clip",
            sourceDuration: 5,
            timelineStart: CMTime(seconds: 10, preferredTimescale: 600)
        )
        secondClip.trackID = sourceTrack.id
        sourceTrack.addClip(secondClip)

        // Arrange: Move first clip forward with ripple
        let newRange = CMTimeRange(start: CMTime(seconds: 15, preferredTimescale: 600), duration: CMTime(seconds: 10, preferredTimescale: 600))
        let operation = MoveClipOperation(
            clipID: testClip.id,
            newRange: newRange,
            newTrackID: sourceTrack.id,
            ripple: true,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Execute, undo, then redo
        try operation.execute()
        try operation.undo()
        try operation.redo()

        // Assert: First clip moved to new position
        let movedClip = sourceTrack.clips.first { $0.id == testClip.id }
        XCTAssertEqual(movedClip!.timeRangeInTimeline.start, newRange.start)

        // Assert: Second clip shifted forward again
        let shiftedClip = sourceTrack.clips.first { $0.id == secondClip.id }
        XCTAssertEqual(shiftedClip!.timeRangeInTimeline.start, CMTime(seconds: 25, preferredTimescale: 600))
    }

    // MARK: - Test Description

    func testDescriptionShowsTrackAndPosition() throws {
        // Arrange: Create operation with specific details
        let newRange = CMTimeRange(start: CMTime(seconds: 3.5, preferredTimescale: 600), duration: CMTime(seconds: 7.2, preferredTimescale: 600))
        let operation = MoveClipOperation(
            clipID: testClip.id,
            newRange: newRange,
            newTrackID: targetTrack.id,
            ripple: false,
            editorState: editorState,
            clipManager: clipManager
        )

        // Assert: Description includes track names and time information
        XCTAssertTrue(operation.description.contains("Move Clip"), "Description should mention 'Move Clip'")
        XCTAssertTrue(operation.description.contains("Test Clip"), "Description should include clip name")
        XCTAssertTrue(operation.description.contains("Source Track"), "Description should include source track name")
        XCTAssertTrue(operation.description.contains("Target Track"), "Description should include target track name")
        XCTAssertTrue(operation.description.contains("10.0"), "Description should include original duration")
        XCTAssertTrue(operation.description.contains("7.2"), "Description should include new duration")
    }

    // MARK: - Edge Cases

    func testExecuteThrowsOnClipNotFound() throws {
        // Arrange: Use non-existent clip ID
        let nonExistentClipID = UUID()
        let newRange = CMTimeRange(start: .zero, duration: .seconds(10))
        let operation = MoveClipOperation(
            clipID: nonExistentClipID,
            newRange: newRange,
            newTrackID: targetTrack.id,
            ripple: false,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act & Assert: Should throw error
        XCTAssertThrowsError(try operation.execute()) { error in
            XCTAssertTrue(error is ClipError, "Should throw ClipError")
            if let clipError = error as? ClipError {
                XCTAssertEqual(clipError, .clipNotFound, "Should be clipNotFound error")
            }
        }
    }

    func testExecuteThrowsOnTrackNotFound() throws {
        // Arrange: Use non-existent track ID
        let nonExistentTrackID = UUID()
        let newRange = CMTimeRange(start: .zero, duration: .seconds(10))
        let operation = MoveClipOperation(
            clipID: testClip.id,
            newRange: newRange,
            newTrackID: nonExistentTrackID,
            ripple: false,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act & Assert: Should throw error
        XCTAssertThrowsError(try operation.execute()) { error in
            XCTAssertTrue(error is ClipError, "Should throw ClipError")
            if let clipError = error as? ClipError {
                XCTAssertEqual(clipError, .trackNotFound, "Should be trackNotFound error")
            }
        }
    }

    func testExecuteThrowsOnOverlap() throws {
        // Arrange: Add a clip to target track that would overlap
        let existingClip = TestDataFactory.makeTestVideoClip(
            name: "Existing Clip",
            sourceDuration: 10,
            timelineStart: CMTime(seconds: 5, preferredTimescale: 600)
        )
        existingClip.trackID = targetTrack.id
        targetTrack.addClip(existingClip)

        // Arrange: Try to move clip to overlapping position
        let newRange = CMTimeRange(start: CMTime(seconds: 8, preferredTimescale: 600), duration: CMTime(seconds: 10, preferredTimescale: 600))
        let operation = MoveClipOperation(
            clipID: testClip.id,
            newRange: newRange,
            newTrackID: targetTrack.id,
            ripple: false,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act & Assert: Should throw error
        XCTAssertThrowsError(try operation.execute()) { error in
            XCTAssertTrue(error is ClipError, "Should throw ClipError")
            if let clipError = error as? ClipError {
                XCTAssertEqual(clipError, .wouldOverlap, "Should be wouldOverlap error")
            }
        }
    }

    func testMoveWithSameTrackDifferentPosition() throws {
        // Arrange: Move clip to same track but different position
        let newRange = CMTimeRange(start: CMTime(seconds: 5, preferredTimescale: 600), duration: CMTime(seconds: 10, preferredTimescale: 600))
        let operation = MoveClipOperation(
            clipID: testClip.id,
            newRange: newRange,
            newTrackID: sourceTrack.id,
            ripple: false,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Execute and verify
        try operation.execute()
        let movedClip = sourceTrack.clips.first { $0.id == testClip.id }
        XCTAssertEqual(movedClip!.timeRangeInTimeline.start, newRange.start)
        XCTAssertEqual(movedClip!.trackID, sourceTrack.id)

        // Act: Undo and verify
        try operation.undo()
        let restoredClip = sourceTrack.clips.first { $0.id == testClip.id }
        XCTAssertEqual(restoredClip!.timeRangeInTimeline.start, .zero)
    }
}