import XCTest
@testable import OpenScreen
import AVFoundation
import CoreMedia

@MainActor
final class ChangeSpeedOperationTests: XCTestCase {
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

        // Create a test clip (10 seconds duration at 1x speed)
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

    func testExecuteChangesSpeed() throws {
        // Arrange: Change clip speed to 2x
        let newSpeed: Float = 2.0
        let operation = ChangeSpeedOperation(
            clipID: testClip.id,
            newSpeed: newSpeed,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Execute the operation
        try operation.execute()

        // Assert: Speed is changed
        XCTAssertEqual(testClip.speed, newSpeed, "Clip speed should be changed to 2.0x")

        // Assert: Timeline duration is halved
        let expectedDuration = CMTime(seconds: 5.0, preferredTimescale: 600) // 10s / 2x = 5s
        XCTAssertEqual(testClip.timelineDuration, expectedDuration, "Timeline duration should be halved")
        XCTAssertEqual(testClip.timeRangeInTimeline.duration, expectedDuration, "Time range duration should be updated")

        // Assert: Source duration unchanged
        XCTAssertEqual(testClip.timeRangeInSource.duration, CMTime(seconds: 10, preferredTimescale: 600), "Source duration should be unchanged")
    }

    func testExecuteChangesSpeedToSlower() throws {
        // Arrange: Change clip speed to 0.5x
        let newSpeed: Float = 0.5
        let operation = ChangeSpeedOperation(
            clipID: testClip.id,
            newSpeed: newSpeed,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Execute the operation
        try operation.execute()

        // Assert: Speed is changed
        XCTAssertEqual(testClip.speed, newSpeed, "Clip speed should be changed to 0.5x")

        // Assert: Timeline duration is doubled
        let expectedDuration = CMTime(seconds: 20.0, preferredTimescale: 600) // 10s / 0.5x = 20s
        XCTAssertEqual(testClip.timelineDuration, expectedDuration, "Timeline duration should be doubled")
        XCTAssertEqual(testClip.timeRangeInTimeline.duration, expectedDuration, "Time range duration should be updated")
    }

    // MARK: - Test Undo

    func testUndoRestoresOriginalSpeed() throws {
        // Arrange: Change speed and then undo
        let newSpeed: Float = 2.0
        let operation = ChangeSpeedOperation(
            clipID: testClip.id,
            newSpeed: newSpeed,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Execute the speed change
        try operation.execute()

        // Verify speed change occurred
        XCTAssertEqual(testClip.speed, newSpeed, "Speed should be 2.0x after execute")

        // Act: Undo the operation
        try operation.undo()

        // Assert: Original speed is restored
        XCTAssertEqual(testClip.speed, 1.0, "Original speed should be restored to 1.0x")

        // Assert: Original timeline duration is restored
        let expectedDuration = CMTime(seconds: 10.0, preferredTimescale: 600)
        XCTAssertEqual(testClip.timelineDuration, expectedDuration, "Original duration should be restored")
        XCTAssertEqual(testClip.timeRangeInTimeline.duration, expectedDuration, "Time range duration should be restored")
    }

    func testUndoMaintainsPosition() throws {
        // Arrange: Create clip not starting at zero
        let clip = TestDataFactory.makeTestVideoClip(
            name: "Positioned Clip",
            sourceDuration: 8,
            timelineStart: CMTime(seconds: 5, preferredTimescale: 600)
        )
        clip.trackID = track.id
        track.removeClip(id: testClip.id)
        track.addClip(clip)

        // Arrange: Change speed and then undo
        let newSpeed: Float = 1.5
        let operation = ChangeSpeedOperation(
            clipID: clip.id,
            newSpeed: newSpeed,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Execute and undo
        try operation.execute()
        try operation.undo()

        // Assert: Start position is unchanged
        XCTAssertEqual(clip.timeRangeInTimeline.start, CMTime(seconds: 5, preferredTimescale: 600), "Start position should be unchanged")

        // Assert: Source duration unchanged
        XCTAssertEqual(clip.timeRangeInSource.duration, CMTime(seconds: 8, preferredTimescale: 600), "Source duration should be unchanged")
    }

    func testUndoPreservesOtherProperties() throws {
        // Arrange: Create clip with custom properties
        let customClip = TestDataFactory.makeTestVideoClip(
            name: "Custom Clip",
            sourceDuration: 10,
            timelineStart: .zero
        )
        customClip.trackID = track.id
        customClip.opacity = 0.8
        customClip.volume = 0.9
        track.removeClip(id: testClip.id)
        track.addClip(customClip)

        // Arrange: Change speed and then undo
        let newSpeed: Float = 2.0
        let operation = ChangeSpeedOperation(
            clipID: customClip.id,
            newSpeed: newSpeed,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Execute and undo
        try operation.execute()
        try operation.undo()

        // Assert: All properties are preserved
        XCTAssertEqual(customClip.speed, 1.0, "Speed should be restored")
        XCTAssertEqual(customClip.opacity, 0.8, "Opacity should be preserved")
        XCTAssertEqual(customClip.volume, 0.9, "Volume should be preserved")
        XCTAssertEqual(customClip.name, "Custom Clip", "Name should be preserved")
        XCTAssertEqual(customClip.timeRangeInSource.duration, CMTime(seconds: 10, preferredTimescale: 600), "Source duration should be preserved")
    }

    // MARK: - Test Redo

    func testRedoChangesSpeedAgain() throws {
        // Arrange: Change, undo, then redo
        let newSpeed: Float = 2.0
        let operation = ChangeSpeedOperation(
            clipID: testClip.id,
            newSpeed: newSpeed,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Change speed, undo, then redo
        try operation.execute()
        try operation.undo()
        try operation.redo()

        // Assert: Speed is changed again
        XCTAssertEqual(testClip.speed, newSpeed, "Speed should be 2.0x after redo")

        // Assert: Timeline duration is halved
        let expectedDuration = CMTime(seconds: 5.0, preferredTimescale: 600)
        XCTAssertEqual(testClip.timelineDuration, expectedDuration, "Timeline duration should be halved")
    }

    func testRedoWithDifferentSpeed() throws {
        // Arrange: Change to 2x, undo, then change to 0.5x
        let firstOperation = ChangeSpeedOperation(
            clipID: testClip.id,
            newSpeed: 2.0,
            editorState: editorState,
            clipManager: clipManager
        )

        let secondOperation = ChangeSpeedOperation(
            clipID: testClip.id,
            newSpeed: 0.5,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: First change
        try firstOperation.execute()
        XCTAssertEqual(testClip.speed, 2.0)

        // Act: Undo and redo with different speed
        try firstOperation.undo()
        try secondOperation.redo()

        // Assert: Speed is 0.5x
        XCTAssertEqual(testClip.speed, 0.5, "Speed should be 0.5x after second redo")

        // Assert: Timeline duration is doubled
        let expectedDuration = CMTime(seconds: 20.0, preferredTimescale: 600)
        XCTAssertEqual(testClip.timelineDuration, expectedDuration, "Timeline duration should be doubled")
    }

    // MARK: - Test Description

    func testDescriptionShowsSpeedChange() throws {
        // Arrange: Create operation with specific speed
        let newSpeed: Float = 1.5
        let operation = ChangeSpeedOperation(
            clipID: testClip.id,
            newSpeed: newSpeed,
            editorState: editorState,
            clipManager: clipManager
        )

        // Assert: Description includes speed change information
        XCTAssertTrue(operation.description.contains("Change Speed"), "Description should mention 'Change Speed'")
        XCTAssertTrue(operation.description.contains("Test Clip"), "Description should include clip name")
        XCTAssertTrue(operation.description.contains("1.0"), "Description should include original speed")
        XCTAssertTrue(operation.description.contains("1.5"), "Description should include new speed")
        XCTAssertTrue(operation.description.contains("10.0"), "Description should include original duration")
    }

    // MARK: - Edge Cases

    func testExecuteThrowsOnInvalidSpeed() throws {
        // Arrange: Try to set speed outside valid range
        let invalidSpeed: Float = 20.0 // Above maximum of 16.0
        let operation = ChangeSpeedOperation(
            clipID: testClip.id,
            newSpeed: invalidSpeed,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act & Assert: Should throw error
        XCTAssertThrowsError(try operation.execute()) { error in
            XCTAssertTrue(error is ClipError, "Should throw ClipError")
            if let clipError = error as? ClipError {
                XCTAssertEqual(clipError, .invalidSpeed, "Should be invalidSpeed error")
            }
        }
    }

    func testExecuteThrowsOnZeroSpeed() throws {
        // Arrange: Try to set zero speed
        let zeroSpeed: Float = 0.0
        let operation = ChangeSpeedOperation(
            clipID: testClip.id,
            newSpeed: zeroSpeed,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act & Assert: Should throw error
        XCTAssertThrowsError(try operation.execute()) { error in
            XCTAssertTrue(error is ClipError, "Should throw ClipError")
            if let clipError = error as? ClipError {
                XCTAssertEqual(clipError, .invalidSpeed, "Should be invalidSpeed error")
            }
        }
    }

    func testMultipleSpeedChanges() throws {
        // Arrange: Change speed multiple times
        let firstOperation = ChangeSpeedOperation(
            clipID: testClip.id,
            newSpeed: 2.0,
            editorState: editorState,
            clipManager: clipManager
        )

        let secondOperation = ChangeSpeedOperation(
            clipID: testClip.id,
            newSpeed: 0.5,
            editorState: editorState,
            clipManager: clipManager
        )

        let thirdOperation = ChangeSpeedOperation(
            clipID: testClip.id,
            newSpeed: 4.0,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: First change
        try firstOperation.execute()
        XCTAssertEqual(testClip.speed, 2.0)
        XCTAssertEqual(CMTimeGetSeconds(testClip.timelineDuration), 5.0)

        // Act: Second change
        try secondOperation.execute()
        XCTAssertEqual(testClip.speed, 0.5)
        XCTAssertEqual(CMTimeGetSeconds(testClip.timelineDuration), 20.0)

        // Act: Third change
        try thirdOperation.execute()
        XCTAssertEqual(testClip.speed, 4.0)
        XCTAssertEqual(CMTimeGetSeconds(testClip.timelineDuration), 2.5)

        // Act: Undo third change
        try thirdOperation.undo()
        XCTAssertEqual(testClip.speed, 0.5)
        XCTAssertEqual(CMTimeGetSeconds(testClip.timelineDuration), 20.0)

        // Act: Undo second change
        try secondOperation.undo()
        XCTAssertEqual(testClip.speed, 2.0)
        XCTAssertEqual(CMTimeGetSeconds(testClip.timelineDuration), 5.0)

        // Act: Undo first change
        try firstOperation.undo()
        XCTAssertEqual(testClip.speed, 1.0)
        XCTAssertEqual(CMTimeGetSeconds(testClip.timelineDuration), 10.0)
    }

    func testSpeedChangeWithSourceRange() throws {
        // Arrange: Create clip with specific source range
        let customClip = TestDataFactory.makeTestVideoClip(
            name: "Custom Clip",
            sourceDuration: 20,
            timelineStart: .zero
        )
        customClip.trackID = track.id
        customClip.timeRangeInSource = CMTimeRange(
            start: CMTime(seconds: 5, preferredTimescale: 600),
            duration: CMTime(seconds: 10, preferredTimescale: 600) // Only use half of source
        )
        track.removeClip(id: testClip.id)
        track.addClip(customClip)

        // Arrange: Change speed to 2x
        let newSpeed: Float = 2.0
        let operation = ChangeSpeedOperation(
            clipID: customClip.id,
            newSpeed: newSpeed,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Execute
        try operation.execute()

        // Assert: Speed changed
        XCTAssertEqual(customClip.speed, 2.0)

        // Assert: Timeline duration halved (5s)
        XCTAssertEqual(CMTimeGetSeconds(customClip.timelineDuration), 5.0, accuracy: 0.01)

        // Assert: Source range unchanged
        XCTAssertEqual(customClip.timeRangeInSource.start, CMTime(seconds: 5, preferredTimescale: 600))
        XCTAssertEqual(customClip.timeRangeInSource.duration, CMTime(seconds: 10, preferredTimescale: 600))

        // Act: Undo
        try operation.undo()

        // Assert: Original speed restored
        XCTAssertEqual(customClip.speed, 1.0)

        // Assert: Original duration restored
        XCTAssertEqual(CMTimeGetSeconds(customClip.timelineDuration), 10.0, accuracy: 0.01)
    }

    func testSpeedChangeAtSpecificPosition() throws {
        // Arrange: Create clip not starting at zero
        let positionedClip = TestDataFactory.makeTestVideoClip(
            name: "Positioned Clip",
            sourceDuration: 10,
            timelineStart: CMTime(seconds: 5, preferredTimescale: 600)
        )
        positionedClip.trackID = track.id
        track.removeClip(id: testClip.id)
        track.addClip(positionedClip)

        // Arrange: Change speed to 1.5x
        let newSpeed: Float = 1.5
        let operation = ChangeSpeedOperation(
            clipID: positionedClip.id,
            newSpeed: newSpeed,
            editorState: editorState,
            clipManager: clipManager
        )

        // Act: Execute
        try operation.execute()

        // Assert: Speed changed
        XCTAssertEqual(positionedClip.speed, 1.5)

        // Assert: Start position unchanged
        XCTAssertEqual(positionedClip.timeRangeInTimeline.start, CMTime(seconds: 5, preferredTimescale: 600))

        // Assert: New duration is 10s / 1.5x = 6.66s
        XCTAssertEqual(CMTimeGetSeconds(positionedClip.timelineDuration), 20.0/3.0, accuracy: 0.01)

        // Act: Undo
        try operation.undo()

        // Assert: Original speed restored
        XCTAssertEqual(positionedClip.speed, 1.0)

        // Assert: Original duration restored
        XCTAssertEqual(CMTimeGetSeconds(positionedClip.timelineDuration), 10.0, accuracy: 0.01)
    }
}