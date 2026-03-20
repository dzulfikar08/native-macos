import XCTest
@testable import OpenScreen
import AVFoundation
import CoreMedia

@MainActor
final class DeleteClipOperationTests: XCTestCase {
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

    func testExecuteDeletesClip() throws {
        // Arrange: Delete clip without ripple
        let operation = DeleteClipOperation(
            clipID: testClip.id,
            ripple: false,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Execute the operation
        try operation.execute()

        // Assert: Clip is removed from track
        XCTAssertNil(track.clips.first { $0.id == testClip.id }, "Clip should be deleted from track")
        XCTAssertEqual(track.clips.count, 0, "Track should be empty after deletion")
    }

    func testExecuteDeletesClipWithRipple() throws {
        // Arrange: Add another clip to track
        let secondClip = TestDataFactory.makeTestVideoClip(
            name: "Second Clip",
            sourceDuration: 5,
            timelineStart: CMTime(seconds: 10, preferredTimescale: 600)
        )
        secondClip.trackID = track.id
        track.addClip(secondClip)

        // Arrange: Delete first clip with ripple
        let operation = DeleteClipOperation(
            clipID: testClip.id,
            ripple: true,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Execute the operation
        try operation.execute()

        // Assert: First clip is deleted
        XCTAssertNil(track.clips.first { $0.id == testClip.id }, "First clip should be deleted")

        // Assert: Second clip shifted left
        let shiftedClip = track.clips.first { $0.name == "Second Clip" }
        XCTAssertNotNil(shiftedClip)
        XCTAssertEqual(shiftedClip!.timeRangeInTimeline.start, .zero)
        XCTAssertEqual(shiftedClip!.timeRangeInTimeline.duration, CMTime(seconds: 5, preferredTimescale: 600))
    }

    // MARK: - Test Undo

    func testUndoRestoresClip() throws {
        // Arrange: Delete clip and then undo
        let operation = DeleteClipOperation(
            clipID: testClip.id,
            ripple: false,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Execute the deletion
        try operation.execute()

        // Verify deletion occurred
        XCTAssertEqual(track.clips.count, 0, "Track should be empty after deletion")

        // Act: Undo the operation
        try operation.undo()

        // Assert: Clip is restored with same ID
        let restoredClip = track.clips.first { $0.id == testClip.id }
        XCTAssertNotNil(restoredClip, "Clip should be restored")

        // Assert: Clip properties are preserved
        XCTAssertEqual(restoredClip!.id, testClip.id)
        XCTAssertEqual(restoredClip!.name, testClip.name)
        XCTAssertEqual(restoredClip!.trackID, testClip.trackID)
        XCTAssertEqual(restoredClip!.timeRangeInSource, testClip.timeRangeInSource)
        XCTAssertEqual(restoredClip!.timeRangeInTimeline, testClip.timeRangeInTimeline)
        XCTAssertEqual(restoredClip!.speed, testClip.speed)
        XCTAssertEqual(restoredClip!.volume, testClip.volume)
        XCTAssertEqual(restoredClip!.opacity, testClip.opacity)

        // Assert: Only one clip on track
        XCTAssertEqual(track.clips.count, 1, "Should have 1 clip after undo")
    }

    func testUndoRestoresClipWithRipple() throws {
        // Arrange: Add another clip to track
        let secondClip = TestDataFactory.makeTestVideoClip(
            name: "Second Clip",
            sourceDuration: 5,
            timelineStart: CMTime(seconds: 10, preferredTimescale: 600)
        )
        secondClip.trackID = track.id
        track.addClip(secondClip)

        // Arrange: Delete first clip with ripple and then undo
        let operation = DeleteClipOperation(
            clipID: testClip.id,
            ripple: true,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Execute the deletion
        try operation.execute()

        // Verify deletion occurred
        XCTAssertNil(track.clips.first { $0.id == testClip.id })
        XCTAssertEqual(track.clips.count, 1, "Should have 1 clip after deletion")

        // Act: Undo the operation
        try operation.undo()

        // Assert: First clip is restored
        let restoredClip = track.clips.first { $0.id == testClip.id }
        XCTAssertNotNil(restoredClip)
        XCTAssertEqual(restoredClip!.timeRangeInTimeline.start, .zero)
        XCTAssertEqual(restoredClip!.timeRangeInTimeline.duration, CMTime(seconds: 10, preferredTimescale: 600))

        // Assert: Second clip is back at original position
        let secondClipRestored = track.clips.first { $0.name == "Second Clip" }
        XCTAssertNotNil(secondClipRestored)
        XCTAssertEqual(secondClipRestored!.timeRangeInTimeline.start, CMTime(seconds: 10, preferredTimescale: 600))
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
        customClip.opacity = 0.8
        customClip.volume = 0.9
        track.addClip(customClip)

        // Arrange: Delete clip and then undo
        let operation = DeleteClipOperation(
            clipID: customClip.id,
            ripple: false,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Execute and undo
        try operation.execute()
        try operation.undo()

        // Assert: All properties are restored
        let restoredClip = track.clips.first { $0.id == customClip.id }
        XCTAssertNotNil(restoredClip)

        XCTAssertEqual(restoredClip!.name, "Custom Clip")
        XCTAssertEqual(restoredClip!.speed, 2.0)
        XCTAssertEqual(restoredClip!.opacity, 0.8)
        XCTAssertEqual(restoredClip!.volume, 0.9)
        XCTAssertEqual(CMTimeGetSeconds(restoredClip!.timeRangeInTimeline.start), 2.0, accuracy: 0.01)
        XCTAssertEqual(CMTimeGetSeconds(restoredClip!.timeRangeInTimeline.duration), 8.0, accuracy: 0.01)
    }

    // MARK: - Test Redo

    func testRedoDeletesAgain() throws {
        // Arrange: Delete, undo, then redo
        let operation = DeleteClipOperation(
            clipID: testClip.id,
            ripple: false,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Delete, undo, then redo
        try operation.execute()
        try operation.undo()
        try operation.redo()

        // Assert: Clip is deleted again
        XCTAssertNil(track.clips.first { $0.id == testClip.id }, "Clip should be deleted after redo")
        XCTAssertEqual(track.clips.count, 0, "Track should be empty after redo")
    }

    func testRedoDeletesAgainWithRipple() throws {
        // Arrange: Add another clip to track
        let secondClip = TestDataFactory.makeTestVideoClip(
            name: "Second Clip",
            sourceDuration: 5,
            timelineStart: CMTime(seconds: 10, preferredTimescale: 600)
        )
        secondClip.trackID = track.id
        track.addClip(secondClip)

        // Arrange: Delete first clip with ripple, undo, then redo
        let operation = DeleteClipOperation(
            clipID: testClip.id,
            ripple: true,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Delete, undo, then redo
        try operation.execute()
        try operation.undo()
        try operation.redo()

        // Assert: First clip is deleted
        XCTAssertNil(track.clips.first { $0.id == testClip.id })

        // Assert: Second clip shifted left
        let shiftedClip = track.clips.first { $0.name == "Second Clip" }
        XCTAssertEqual(shiftedClip!.timeRangeInTimeline.start, .zero)
    }

    // MARK: - Test Description

    func testDescriptionShowsClipName() throws {
        // Arrange: Create operation with specific clip
        let operation = DeleteClipOperation(
            clipID: testClip.id,
            ripple: false,
            editorState: editorState,
            clipManager: clipManager
        )

        // Assert: Description includes clip name
        XCTAssertTrue(operation.description.contains("Delete Clip"), "Description should mention 'Delete Clip'")
        XCTAssertTrue(operation.description.contains("Test Clip"), "Description should include clip name")
        XCTAssertTrue(operation.description.contains("10.0"), "Description should include clip duration")
    }

    func testDescriptionShowsRippleInformation() throws {
        // Arrange: Create operation with ripple
        let operation = DeleteClipOperation(
            clipID: testClip.id,
            ripple: true,
            editorState: editorState,
            clipManager: clipManager
        )

        // Assert: Description reflects ripple operation
        XCTAssertTrue(operation.description.contains("Delete Clip"), "Description should mention 'Delete Clip'")
        XCTAssertTrue(operation.description.contains("Test Clip"), "Description should include clip name")
    }

    // MARK: - Edge Cases

    func testExecuteThrowsOnClipNotFound() throws {
        // Arrange: Use non-existent clip ID
        let nonExistentClipID = UUID()
        let operation = DeleteClipOperation(
            clipID: nonExistentClipID,
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

    func testExecuteOnEmptyTrack() throws {
        // Arrange: Remove clip from track
        track.removeClip(id: testClip.id)
        XCTAssertEqual(track.clips.count, 0, "Track should be empty")

        // Arrange: Try to delete non-existent clip
        let operation = DeleteClipOperation(
            clipID: testClip.id,
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

    func testUndoOnDeletedClip() throws {
        // Arrange: Delete clip multiple times and try to undo
        let operation = DeleteClipOperation(
            clipID: testClip.id,
            ripple: false,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Execute multiple times
        try operation.execute()
        XCTAssertEqual(track.clips.count, 0, "Track should be empty")

        try operation.undo()
        XCTAssertEqual(track.clips.count, 1, "Track should have 1 clip after undo")

        try operation.redo()
        XCTAssertEqual(track.clips.count, 0, "Track should be empty after redo")

        try operation.undo()
        XCTAssertEqual(track.clips.count, 1, "Track should have 1 clip after second undo")

        // Assert: Final state is correct
        let restoredClip = track.clips.first { $0.id == testClip.id }
        XCTAssertNotNil(restoredClip)
        XCTAssertEqual(restoredClip!.name, "Test Clip")
    }

    func testDeleteWithMultipleTracks() throws {
        // Arrange: Create another track
        let secondTrack = ClipTrack(id: UUID(), name: "Second Track", type: .video)
        editorState.clipTracks.append(secondTrack)

        // Arrange: Add clip to second track
        let secondClip = TestDataFactory.makeTestVideoClip(
            name: "Second Track Clip",
            sourceDuration: 5,
            timelineStart: .zero
        )
        secondClip.trackID = secondTrack.id
        secondTrack.addClip(secondClip)

        // Arrange: Delete clip from first track
        let operation = DeleteClipOperation(
            clipID: testClip.id,
            ripple: false,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Execute and undo
        try operation.execute()
        XCTAssertEqual(track.clips.count, 0, "First track should be empty")
        XCTAssertEqual(secondTrack.clips.count, 1, "Second track should still have clip")

        try operation.undo()
        XCTAssertEqual(track.clips.count, 1, "First track should have clip restored")
        XCTAssertEqual(secondTrack.clips.count, 1, "Second track should still have clip")
    }
}