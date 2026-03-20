import XCTest
@testable import OpenScreen
import AVFoundation
import CoreMedia

@MainActor
final class DuplicateClipOperationTests: XCTestCase {
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

    func testExecuteDuplicatesClip() throws {
        // Arrange: Duplicate clip to different position
        let newRange = CMTimeRange(start: CMTime(seconds: 15, preferredTimescale: 600), duration: CMTime(seconds: 10, preferredTimescale: 600))
        let operation = DuplicateClipOperation(
            clipID: testClip.id,
            newRange: newRange,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Execute the operation
        try operation.execute()

        // Assert: Original clip still exists
        XCTAssertNotNil(track.clips.first { $0.id == testClip.id }, "Original clip should still exist")

        // Assert: Duplicate clip exists
        let duplicateClip = track.clips.first { $0.name == "Test Clip copy" }
        XCTAssertNotNil(duplicateClip, "Duplicate clip should exist")

        // Assert: Duplicate has correct properties
        XCTAssertEqual(duplicateClip!.timeRangeInTimeline.start, newRange.start)
        XCTAssertEqual(duplicateClip!.timeRangeInTimeline.duration, newRange.duration)
        XCTAssertEqual(duplicateClip!.trackID, track.id)
        XCTAssertEqual(duplicateClip!.speed, testClip.speed)
        XCTAssertEqual(duplicateClip!.volume, testClip.volume)
        XCTAssertEqual(duplicateClip!.opacity, testClip.opacity)
        XCTAssertEqual(duplicateClip!.asset, testClip.asset)

        // Assert: Track has 2 clips
        XCTAssertEqual(track.clips.count, 2, "Track should have 2 clips")
    }

    func testExecuteDuplicatesClipWithDifferentDuration() throws {
        // Arrange: Duplicate clip with different duration
        let newRange = CMTimeRange(start: CMTime(seconds: 20, preferredTimescale: 600), duration: CMTime(seconds: 5, preferredTimescale: 600))
        let operation = DuplicateClipOperation(
            clipID: testClip.id,
            newRange: newRange,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Execute the operation
        try operation.execute()

        // Assert: Duplicate exists with correct duration
        let duplicateClip = track.clips.first { $0.name == "Test Clip copy" }
        XCTAssertNotNil(duplicateClip)
        XCTAssertEqual(CMTimeGetSeconds(duplicateClip!.timeRangeInTimeline.duration), 5.0, accuracy: 0.01)
        XCTAssertEqual(CMTimeGetSeconds(duplicateClip!.timeRangeInSource.duration), 5.0, accuracy: 0.01)

        // Assert: Source duration unchanged
        XCTAssertEqual(CMTimeGetSeconds(testClip.timeRangeInSource.duration), 10.0, accuracy: 0.01)
    }

    // MARK: - Test Undo

    func testUndoRemovesDuplicate() throws {
        // Arrange: Duplicate clip and then undo
        let newRange = CMTimeRange(start: CMTime(seconds: 15, preferredTimescale: 600), duration: CMTime(seconds: 10, preferredTimescale: 600))
        let operation = DuplicateClipOperation(
            clipID: testClip.id,
            newRange: newRange,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Execute the duplication
        try operation.execute()

        // Verify duplication occurred
        XCTAssertEqual(track.clips.count, 2, "Should have 2 clips after duplication")
        XCTAssertNotNil(track.clips.first { $0.name == "Test Clip copy" }, "Duplicate should exist")

        // Act: Undo the operation
        try operation.undo()

        // Assert: Original clip still exists
        XCTAssertNotNil(track.clips.first { $0.id == testClip.id }, "Original clip should still exist")

        // Assert: Duplicate clip is removed
        XCTAssertNil(track.clips.first { $0.name == "Test Clip copy" }, "Duplicate should be removed")

        // Assert: Track has 1 clip
        XCTAssertEqual(track.clips.count, 1, "Should have 1 clip after undo")
    }

    func testUndoRestoresOriginalClipCount() throws {
        // Arrange: Add another clip to track
        let secondClip = TestDataFactory.makeTestVideoClip(
            name: "Second Clip",
            sourceDuration: 5,
            timelineStart: CMTime(seconds: 10, preferredTimescale: 600)
        )
        secondClip.trackID = track.id
        track.addClip(secondClip)

        let initialClipCount = track.clips.count

        // Arrange: Duplicate clip and then undo
        let newRange = CMTimeRange(start: CMTime(seconds: 20, preferredTimescale: 600), duration: CMTime(seconds: 10, preferredTimescale: 600))
        let operation = DuplicateClipOperation(
            clipID: testClip.id,
            newRange: newRange,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Execute and undo
        try operation.execute()
        XCTAssertEqual(track.clips.count, initialClipCount + 1, "Should have one more clip after duplication")

        try operation.undo()
        XCTAssertEqual(track.clips.count, initialClipCount, "Clip count should be restored to original")
    }

    // MARK: - Test Redo

    func testRedoDuplicatesAgain() throws {
        // Arrange: Duplicate, undo, then redo
        let newRange = CMTimeRange(start: CMTime(seconds: 15, preferredTimescale: 600), duration: CMTime(seconds: 10, preferredTimescale: 600))
        let operation = DuplicateClipOperation(
            clipID: testClip.id,
            newRange: newRange,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Duplicate, undo, then redo
        try operation.execute()
        try operation.undo()
        try operation.redo()

        // Assert: Original clip still exists
        XCTAssertNotNil(track.clips.first { $0.id == testClip.id }, "Original clip should still exist")

        // Assert: Duplicate clip exists again
        let duplicateClip = track.clips.first { $0.name == "Test Clip copy" }
        XCTAssertNotNil(duplicateClip, "Duplicate clip should exist after redo")

        // Assert: Duplicate has correct position
        XCTAssertEqual(duplicateClip!.timeRangeInTimeline.start, newRange.start)
        XCTAssertEqual(duplicateClip!.timeRangeInTimeline.duration, newRange.duration)

        // Assert: Track has 2 clips
        XCTAssertEqual(track.clips.count, 2, "Should have 2 clips after redo")
    }

    func testRedoCreatesNewDuplicateID() throws {
        // Arrange: Duplicate, undo, then redo
        let newRange = CMTimeRange(start: CMTime(seconds: 15, preferredTimescale: 600), duration: CMTime(seconds: 10, preferredTimescale: 600))
        let operation = DuplicateClipOperation(
            clipID: testClip.id,
            newRange: newRange,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Execute and capture first duplicate ID
        try operation.execute()
        let firstDuplicateID = operation.duplicatedClipID
        XCTAssertNotNil(firstDuplicateID)

        // Act: Undo and redo
        try operation.undo()
        try operation.redo()
        let secondDuplicateID = operation.duplicatedClipID

        // Assert: Duplicate clips have different IDs
        XCTAssertNotEqual(firstDuplicateID, secondDuplicateID, "Redo should create a new duplicate with different ID")

        // Assert: Both original and new duplicate exist
        XCTAssertEqual(track.clips.count, 2, "Should have 2 clips after redo")

        // Assert: Only one copy exists (old one was removed in undo)
        let duplicateClips = track.clips.filter { $0.name == "Test Clip copy" }
        XCTAssertEqual(duplicateClips.count, 1, "Should have exactly one copy after redo")
    }

    // MARK: - Test Description

    func testDescriptionShowsPosition() throws {
        // Arrange: Create operation with specific position
        let newRange = CMTimeRange(start: CMTime(seconds: 3.5, preferredTimescale: 600), duration: CMTime(seconds: 7.2, preferredTimescale: 600))
        let operation = DuplicateClipOperation(
            clipID: testClip.id,
            newRange: newRange,
            editorState: editorState,
            clipManager: clipManager
        )

        // Assert: Description includes position and time information
        XCTAssertTrue(operation.description.contains("Duplicate Clip"), "Description should mention 'Duplicate Clip'")
        XCTAssertTrue(operation.description.contains("Test Clip"), "Description should include clip name")
        XCTAssertTrue(operation.description.contains("Test Track"), "Description should include track name")
        XCTAssertTrue(operation.description.contains("10.0"), "Description should include original duration")
        XCTAssertTrue(operation.description.contains("7.2"), "Description should include new duration")
    }

    // MARK: - Edge Cases

    func testExecuteThrowsOnClipNotFound() throws {
        // Arrange: Use non-existent clip ID
        let nonExistentClipID = UUID()
        let newRange = CMTimeRange(start: .zero, duration: .seconds(10))
        let operation = DuplicateClipOperation(
            clipID: nonExistentClipID,
            newRange: newRange,
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

    func testExecuteThrowsOnOverlap() throws {
        // Arrange: Add a clip that would overlap with new position
        let existingClip = TestDataFactory.makeTestVideoClip(
            name: "Existing Clip",
            sourceDuration: 10,
            timelineStart: CMTime(seconds: 15, preferredTimescale: 600)
        )
        existingClip.trackID = track.id
        track.addClip(existingClip)

        // Arrange: Try to duplicate clip to overlapping position
        let newRange = CMTimeRange(start: CMTime(seconds: 18, preferredTimescale: 600), duration: CMTime(seconds: 5, preferredTimescale: 600))
        let operation = DuplicateClipOperation(
            clipID: testClip.id,
            newRange: newRange,
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

    func testDuplicateClipMaintainsAllProperties() throws {
        // Arrange: Create clip with custom properties
        let customClip = TestDataFactory.makeTestVideoClip(
            name: "Custom Clip",
            speed: 1.5,
            sourceDuration: 8,
            timelineStart: CMTime(seconds: 2, preferredTimescale: 600)
        )
        customClip.trackID = track.id
        customClip.opacity = 0.7
        customClip.volume = 0.8
        track.removeClip(id: testClip.id)
        track.addClip(customClip)

        // Arrange: Duplicate clip
        let newRange = CMTimeRange(start: CMTime(seconds: 15, preferredTimescale: 600), duration: CMTime(seconds: 8, preferredTimescale: 600))
        let operation = DuplicateClipOperation(
            clipID: customClip.id,
            newRange: newRange,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Execute and verify
        try operation.execute()

        let duplicateClip = track.clips.first { $0.name == "Custom Clip copy" }
        XCTAssertNotNil(duplicateClip)

        // Assert: All properties are copied correctly
        XCTAssertEqual(duplicateClip!.speed, 1.5)
        XCTAssertEqual(duplicateClip!.opacity, 0.7)
        XCTAssertEqual(duplicateClip!.volume, 0.8)
        XCTAssertEqual(duplicateClip!.timeRangeInSource, customClip.timeRangeInSource)
        XCTAssertEqual(duplicateClip!.asset, customClip.asset)

        // Act: Undo and verify properties are preserved
        try operation.undo()

        let restoredClip = track.clips.first { $0.id == customClip.id }
        XCTAssertEqual(restoredClip!.speed, 1.5)
        XCTAssertEqual(restoredClip!.opacity, 0.7)
        XCTAssertEqual(restoredClip!.volume, 0.8)
    }

    func testMultipleSequentialDuplicates() throws {
        // Arrange: Duplicate clip multiple times
        let firstOperation = DuplicateClipOperation(
            clipID: testClip.id,
            newRange: CMTimeRange(start: CMTime(seconds: 15, preferredTimescale: 600), duration: CMTime(seconds: 10, preferredTimescale: 600)),
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: First duplicate
        try firstOperation.execute()
        XCTAssertEqual(track.clips.count, 2, "Should have 2 clips after first duplication")

        // Act: Second duplicate
        let secondOperation = DuplicateClipOperation(
            clipID: testClip.id,
            newRange: CMTimeRange(start: CMTime(seconds: 30, preferredTimescale: 600), duration: CMTime(seconds: 10, preferredTimescale: 600)),
            editorState: editorState,
            clipManager: clipManager
        )
        try secondOperation.execute()
        XCTAssertEqual(track.clips.count, 3, "Should have 3 clips after second duplication")

        // Act: Undo second duplicate
        try secondOperation.undo()
        XCTAssertEqual(track.clips.count, 2, "Should have 2 clips after undoing second duplication")

        // Act: Undo first duplicate
        try firstOperation.undo()
        XCTAssertEqual(track.clips.count, 1, "Should have 1 clip after undoing first duplication")
    }

    func testDuplicateClipWithSameStartPosition() throws {
        // Arrange: Duplicate clip to same start position but different duration
        let newRange = CMTimeRange(start: .zero, duration: CMTime(seconds: 5, preferredTimescale: 600))
        let operation = DuplicateClipOperation(
            clipID: testClip.id,
            newRange: newRange,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Execute
        try operation.execute()

        // Assert: Both clips exist, but different durations
        let originalClip = track.clips.first { $0.id == testClip.id }
        let duplicateClip = track.clips.first { $0.name == "Test Clip copy" }

        XCTAssertNotNil(originalClip)
        XCTAssertNotNil(duplicateClip)
        XCTAssertEqual(originalClip!.timeRangeInTimeline.duration, CMTime(seconds: 10, preferredTimescale: 600))
        XCTAssertEqual(duplicateClip!.timeRangeInTimeline.duration, CMTime(seconds: 5, preferredTimescale: 600))
    }
}