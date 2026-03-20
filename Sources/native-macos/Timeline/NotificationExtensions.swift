import Foundation

extension Notification.Name {
    /// Notification posted when playback state changes (playing/paused)
    static let playbackStateChanged = Notification.Name("com.openscreen.playback.stateChanged")

    /// Notification posted when timeline seek is performed
    static let timelineSeekPerformed = Notification.Name("com.openscreen.timeline.seekPerformed")

    /// Notification posted when recording completes
    static let recordingDidComplete = Notification.Name("com.openscreen.recording.didComplete")

    // MARK: - Export Notifications
    /// Notification posted when export begins
    static let didBeginExport = Notification.Name("com.openscreen.export.didBeginExport")

    /// Notification posted when export progress updates
    static let exportProgress = Notification.Name("com.openscreen.export.progress")

    /// Notification posted when export completes successfully
    static let didCompleteExport = Notification.Name("com.openscreen.export.didCompleteExport")

    /// Notification posted when export is cancelled
    static let didCancelExport = Notification.Name("com.openscreen.export.didCancelExport")

    /// Notification posted when export fails
    static let didFailExport = Notification.Name("com.openscreen.export.didFailExport")

    /// Notification posted when timeline edit mode changes
    static let timelineEditModeDidChange = Notification.Name("timelineEditModeDidChange")

    // MARK: - Clip Operation Notifications

    /// Notification posted when a clip is split
    static let clipDidSplit = Notification.Name("clipDidSplit")

    /// Notification posted when a clip is trimmed
    static let clipDidTrim = Notification.Name("clipDidTrim")

    /// Notification posted when a clip is moved
    static let clipDidMove = Notification.Name("clipDidMove")

    /// Notification posted when a clip is deleted
    static let clipDidDelete = Notification.Name("clipDidDelete")

    /// Notification posted when a clip is duplicated
    static let clipDidDuplicate = Notification.Name("clipDidDuplicate")

    /// Notification posted when a clip's speed changes
    static let clipDidChangeSpeed = Notification.Name("clipDidChangeSpeed")

    // MARK: - Undo/Redo Notifications

    /// Notification posted when the undo stack changes
    static let undoStackDidChange = Notification.Name("undoStackDidChange")

    /// Notification posted when the redo stack changes
    static let redoStackDidChange = Notification.Name("redoStackDidChange")

    /// userInfo key for the undo operation description
    static let undoOperationKey = "undoOperation"

    /// userInfo key for the redo operation description
    static let redoOperationKey = "redoOperation"

    /// userInfo key for whether undo is available
    static let canUndoKey = "canUndo"

    /// userInfo key for whether redo is available
    static let canRedoKey = "canRedo"

    // MARK: - Timeline UI Notifications

    /// Notification posted when timeline clip selection changes
    static let timelineClipSelectionChanged = Notification.Name("timelineClipSelectionChanged")

    /// Notification posted when a clip is being dragged on the timeline
    static let timelineClipDragging = Notification.Name("timelineClipDragging")

    /// Notification posted when timeline drag operation ends
    static let timelineDragEnded = Notification.Name("timelineDragEnded")

    /// Notification posted when timeline drag is cancelled
    static let timelineDragCancelled = Notification.Name("timelineDragCancelled")

    /// Notification posted when playhead position changes
    static let timelinePlayheadMoved = Notification.Name("timelinePlayheadMoved")

    /// Notification posted when a clip move operation completes
    static let timelineClipMoved = Notification.Name("timelineClipMoved")

    // MARK: - Transition Notifications

    /// Notification posted when transition drag starts
    /// userInfo contains: "transitionID" (UUID), "edge" (TransitionEdge)
    static let transitionDragStarted = Notification.Name("transitionDragStarted")

    /// Notification posted while transition is being dragged
    /// userInfo contains: "transitionID" (UUID), "offset" (CGFloat)
    static let transitionDragging = Notification.Name("transitionDragging")

    /// Notification posted when transition drag ends
    static let transitionDragEnded = Notification.Name("transitionDragEnded")

    /// Notification posted when transition drag is cancelled
    static let transitionDragCancelled = Notification.Name("transitionDragCancelled")

    /// Notification posted when transition duration changes
    /// userInfo contains: "transitionID" (UUID), "oldDuration" (CMTime), "newDuration" (CMTime)
    static let transitionDurationChanged = Notification.Name("transitionDurationChanged")

    /// Notification posted when transition is created successfully
    /// userInfo contains: "transitionID" (UUID)
    static let transitionCreated = Notification.Name("transitionCreated")

    /// Notification posted when transition creation fails
    /// userInfo contains: "error" (String)
    static let transitionCreationFailed = Notification.Name("transitionCreationFailed")

    /// Notification posted when transition is deleted
    /// userInfo contains: "transitionID" (UUID)
    static let transitionDeleted = Notification.Name("transitionDeleted")

    // MARK: - Transition userInfo Keys

    /// userInfo key for transition ID
    static let transitionIDKey = "transitionID"

    /// userInfo key for transition edge (leading or trailing)
    static let edgeKey = "edge"

    /// userInfo key for drag offset
    static let offsetKey = "offset"

    /// userInfo key for old duration
    static let oldDurationKey = "oldDuration"

    /// userInfo key for new duration
    static let newDurationKey = "newDuration"
}
