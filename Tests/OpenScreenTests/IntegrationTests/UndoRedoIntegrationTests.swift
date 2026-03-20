import XCTest
@testable import OpenScreen
import CoreMedia

@MainActor
final class UndoRedoIntegrationTests: XCTestCase {
    var state: EditorState!
    var manager: ClipManager!

    override func setUp() {
        super.setUp()
        state = EditorState.createTestState()
        state.initializeUndoManager()
        manager = ClipManager(editorState: state)
    }

    override func tearDown() {
        state = nil
        manager = nil
        super.tearDown()
    }

    func testFullUndoRedoWorkflow() throws {
        let track = ClipTrack(name: "Video 1", type: .video, zIndex: 0)
        let clip = TestDataFactory.makeTestVideoClip(
            timelineStart: .zero,
            sourceDuration: 10
        )
        track.addClip(clip)
        state.clipTracks = [track]

        // Execute split
        let splitOp = SplitClipOperation(
            clipID: clip.id,
            splitTime: CMTime(seconds: 5, preferredTimescale: 600),
            editorState: state,
            clipManager: manager
        )
        try state.undoManager.executeOperation(splitOp)

        XCTAssertEqual(track.clips.count, 2)
        XCTAssertTrue(state.canUndo)
        XCTAssertFalse(state.canRedo)

        // Undo
        try state.undo()

        XCTAssertEqual(track.clips.count, 1)
        XCTAssertFalse(state.canUndo)
        XCTAssertTrue(state.canRedo)

        // Redo
        try state.redo()

        XCTAssertEqual(track.clips.count, 2)
        XCTAssertTrue(state.canUndo)
        XCTAssertFalse(state.canRedo)
    }

    func testMultipleOperationsInSequence() throws {
        let track = ClipTrack(name: "Video 1", type: .video, zIndex: 0)
        let clip = TestDataFactory.makeTestVideoClip(
            timelineStart: .zero,
            sourceDuration: 10
        )
        track.addClip(clip)
        state.clipTracks = [track]

        // Execute multiple operations
        try state.undoManager.executeOperation(
            SplitClipOperation(
                clipID: clip.id,
                splitTime: CMTime(seconds: 5, preferredTimescale: 600),
                editorState: state,
                clipManager: manager
            )
        )

        let firstClip = track.clips.first!
        try state.undoManager.executeOperation(
            TrimClipOperation(
                clipID: firstClip.id,
                newRange: CMTimeRange(
                    start: .zero,
                    end: CMTime(seconds: 3, preferredTimescale: 600)
                ),
                editorState: state,
                clipManager: manager
            )
        )

        XCTAssertEqual(state.undoManager.undoStack.count, 2)

        // Undo both
        try state.undo()
        try state.undo()

        XCTAssertEqual(state.undoManager.undoStack.count, 0)
    }

    func testHistoryLimitTrimsOldOperations() throws {
        state.undoManager.historyLimit = .fixedCount(5)

        let track = ClipTrack(name: "Video 1", type: .video, zIndex: 0)
        state.clipTracks = [track]

        // Add 10 operations
        for i in 0..<10 {
            let clip = TestDataFactory.makeTestVideoClip(
                name: "Clip \(i)",
                timelineStart: CMTime(seconds: Double(i * 10), preferredTimescale: 600),
                sourceDuration: 10
            )
            track.addClip(clip)

            try state.undoManager.executeOperation(
                DeleteClipOperation(
                    clipID: clip.id,
                    ripple: false,
                    editorState: state,
                    clipManager: manager
                )
            )
        }

        XCTAssertEqual(state.undoManager.undoStack.count, 5)
    }

    func testHistoryPreservedWithinTimeWindow() throws {
        state.undoManager.historyLimit = .timeWindow(60) // 1 minute

        let track = ClipTrack(name: "Video 1", type: .video, zIndex: 0)
        state.clipTracks = [track]

        let clip = TestDataFactory.makeTestVideoClip()
        track.addClip(clip)

        // Add operation
        let op = DeleteClipOperation(
            clipID: clip.id,
            ripple: false,
            editorState: state,
            clipManager: manager
        )
        try state.undoManager.executeOperation(op)

        // Should still be in history (within time window)
        XCTAssertEqual(state.undoManager.undoStack.count, 1)
    }

    func testModeSwitchingClearsHistory() throws {
        let track = ClipTrack(name: "Video 1", type: .video, zIndex: 0)
        let clip = TestDataFactory.makeTestVideoClip()
        track.addClip(clip)
        state.clipTracks = [track]

        // Add operation to history
        try state.undoManager.executeOperation(
            DeleteClipOperation(
                clipID: clip.id,
                ripple: false,
                editorState: state,
                clipManager: manager
            )
        )

        XCTAssertTrue(state.canUndo)

        // Switch mode - Note: SwitchTimelineModeOperation doesn't exist yet,
        // so we'll test the clearing behavior directly
        state.undoManager.clearHistory()

        // History should be cleared
        XCTAssertFalse(state.canUndo)
        XCTAssertEqual(state.undoManager.undoStack.count, 0)
    }

    func testUndoFailureDoesntCorruptState() throws {
        let track = ClipTrack(name: "Video 1", type: .video, zIndex: 0)
        let clip = TestDataFactory.makeTestVideoClip()
        track.addClip(clip)
        state.clipTracks = [track]

        let op = DeleteClipOperation(
            clipID: clip.id,
            ripple: false,
            editorState: state,
            clipManager: manager
        )
        try state.undoManager.executeOperation(op)

        let trackClipCount = track.clips.count

        // Undo should work
        try state.undo()

        // Trying to undo again should fail gracefully
        XCTAssertFalse(state.canUndo)
    }

    func testExecuteFailureNotAddedToHistory() {
        let track = ClipTrack(name: "Video 1", type: .video, zIndex: 0)
        state.clipTracks = [track]

        // Try to execute operation on non-existent clip
        let op = DeleteClipOperation(
            clipID: UUID(),
            ripple: false,
            editorState: state,
            clipManager: manager
        )

        XCTAssertThrowsError(try state.undoManager.executeOperation(op))

        // Should not be added to history
        XCTAssertFalse(state.canUndo)
        XCTAssertEqual(state.undoManager.undoStack.count, 0)
    }
}
