import Foundation
import CoreMedia
import Combine

/// View model for timeline UI, bridging views to data layer.
/// ObservableObject for SwiftUI reactive updates
@MainActor
final class TimelineViewModel: ObservableObject {
    /// Reference to the editor state
    private(set) var editorState: EditorState

    /// Currently selected clip IDs
    @Published private(set) var selectedClipIDs: Set<UUID> = []

    /// Current playhead position
    @Published private(set) var playheadPosition: CMTime

    /// Drag offset from original position
    @Published private(set) var dragOffset: CGSize = .zero

    /// Drag start position
    private(set) var dragStartPosition: CGPoint = .zero

    // MARK: - Transition Properties

    /// All transitions in the timeline
    @Published private(set) var transitions: [TransitionClip] = []

    /// Currently selected transition ID
    @Published private(set) var selectedTransitionID: UUID? {
        didSet { objectWillChange.send() }
    }

    /// Currently dragging transition (for duration adjustment)
    @Published private(set) var draggingTransitionID: UUID? {
        didSet { objectWillChange.send() }
    }

    /// Drag handle being dragged (leading or trailing edge)
    @Published private(set) var draggingTransitionEdge: TransitionEdge? {
        didSet { objectWillChange.send() }
    }

    /// Original duration before drag (for cancellation)
    private var originalTransitionDuration: CMTime = .zero

    /// Layout cache for transition positioning
    private(set) var transitionLayoutCache: TransitionLayoutCache

    /// Layout cache for clip positioning
    private(set) var layoutCache: ClipLayoutCache

    /// Edges of a transition that can be dragged
    enum TransitionEdge {
        case leading  // Left edge (start time)
        case trailing  // Right edge (end time)
    }

    /// Creates a new timeline view model
    /// - Parameter editorState: The editor state
    init(editorState: EditorState) {
        self.editorState = editorState
        self.playheadPosition = .zero
        self.transitionLayoutCache = TransitionLayoutCache()
        self.layoutCache = ClipLayoutCache()

        // Sync transitions from editor state
        syncTransitions()

        // Observe transition changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(transitionsDidChange(_:)),
            name: .transitionsChanged,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Called when transitions change in EditorState
    @objc private func transitionsDidChange(_ notification: Notification) {
        syncTransitions()
    }
}

// MARK: - Computed Properties

extension TimelineViewModel {
    /// All tracks in the timeline
    var tracks: [ClipTrack] {
        return editorState.clipTracks
    }

    /// Current timeline edit mode
    var timelineEditMode: TimelineEditMode {
        return editorState.timelineEditMode
    }
}

// MARK: - Selection Methods

extension TimelineViewModel {
    /// Selects a single clip
    /// - Parameter clipID: ID of clip to select
    func selectClip(_ clipID: UUID) {
        selectedClipIDs = [clipID]
        // Deselect transition when clip selected
        selectedTransitionID = nil
        postSelectionChangeNotification()
    }

    /// Selects multiple clips
    /// - Parameter clipIDs: IDs of clips to select
    func selectClips(_ clipIDs: [UUID]) {
        selectedClipIDs = Set(clipIDs)
        // Deselect transition when clips selected
        selectedTransitionID = nil
        postSelectionChangeNotification()
    }

    /// Deselects all clips and transitions
    func deselectAll() {
        selectedClipIDs = []
        selectedTransitionID = nil
        postSelectionChangeNotification()
    }

    /// Checks if a clip is selected
    /// - Parameter clipID: ID of clip to check
    /// - Returns: True if clip is selected
    func isClipSelected(_ clipID: UUID) -> Bool {
        return selectedClipIDs.contains(clipID)
    }

    private func postSelectionChangeNotification() {
        NotificationCenter.default.post(
            name: .timelineClipSelectionChanged,
            object: self,
            userInfo: ["selectedClipIDs": selectedClipIDs]
        )
    }
}

// MARK: - Playhead Methods

extension TimelineViewModel {
    /// Sets the playhead position
    /// - Parameter position: New playhead position
    func setPlayheadPosition(_ position: CMTime) {
        playheadPosition = position
        NotificationCenter.default.post(
            name: .timelinePlayheadMoved,
            object: self,
            userInfo: ["position": position]
        )
    }
}

// MARK: - Transition Queries

extension TimelineViewModel {
    /// Returns transitions for a specific track
    func transitions(for trackID: UUID) -> [TransitionClip] {
        return transitions.filter { transition in
            // Find clips on this track
            let trackClips = tracks.first(where: { $0.id == trackID })?.clips ?? []
            let clipIDs = Set(trackClips.map { $0.id })
            return clipIDs.contains(transition.leadingClipID) || clipIDs.contains(transition.trailingClipID)
        }
    }

    /// Returns transition at a given point in timeline coordinates
    func transition(at point: CGPoint, in track: ClipTrack) -> TransitionClip? {
        // NOTE: This will be implemented in Task 2 with TransitionLayoutCache
        // For now, return nil
        return nil
    }

    /// Returns drag handle at a given point
    func dragHandle(at point: CGPoint, for transition: TransitionClip, in track: ClipTrack) -> TransitionEdge? {
        // NOTE: This will be implemented in Task 2 with TransitionLayoutCache
        // For now, return nil
        return nil
    }

    /// Checks if a transition is selected
    func isTransitionSelected(_ id: UUID) -> Bool {
        return selectedTransitionID == id
    }

    /// Returns selected transition
    var selectedTransition: TransitionClip? {
        guard let id = selectedTransitionID else { return nil }
        return transitions.first { $0.id == id }
    }

    /// Returns transition between two specific clips
    /// - Parameters:
    ///   - clipID1: First clip ID
    ///   - clipID2: Second clip ID
    /// - Returns: Transition between the clips, if it exists
    func transition(between clipID1: UUID, and clipID2: UUID) -> TransitionClip? {
        return transitions.first { transition in
            (transition.leadingClipID == clipID1 && transition.trailingClipID == clipID2) ||
            (transition.leadingClipID == clipID2 && transition.trailingClipID == clipID1)
        }
    }
}

// MARK: - Transition Actions

extension TimelineViewModel {
    /// Selects a transition
    func selectTransition(_ id: UUID) {
        selectedTransitionID = id
        // Deselect clips when transition selected
        selectedClipIDs = []
    }

    /// Deselects all transitions
    func deselectTransition() {
        selectedTransitionID = nil
    }

    /// Starts dragging a transition edge for duration adjustment
    func startTransitionDrag(transitionID: UUID, edge: TransitionEdge, at position: CGPoint) {
        guard let transition = transitions.first(where: { $0.id == transitionID }) else {
            return
        }

        draggingTransitionID = transitionID
        draggingTransitionEdge = edge
        originalTransitionDuration = transition.duration
        dragStartPosition = position
        dragOffset = .zero

        // Post notification
        NotificationCenter.default.post(
            name: .transitionDragStarted,
            object: self,
            userInfo: ["transitionID": transitionID, "edge": edge]
        )
    }

    /// Updates transition drag position
    func updateTransitionDrag(at position: CGPoint) {
        guard draggingTransitionID != nil else {
            return
        }

        dragOffset = CGSize(
            width: position.x - dragStartPosition.x,
            height: position.y - dragStartPosition.y
        )

        // Calculate new duration based on drag offset
        // This will be applied during endDrag
    }

    /// Ends transition drag and commits duration change
    func endTransitionDrag() {
        guard
            let transitionID = draggingTransitionID,
            let edge = draggingTransitionEdge,
            var transition = transitions.first(where: { $0.id == transitionID }),
            let track = tracks.first(where: { t in
                t.clips.contains(where: { $0.id == transition.leadingClipID || $0.id == transition.trailingClipID })
            })
        else {
            cancelTransitionDrag()
            return
        }

        // Calculate new duration based on drag offset
        // NOTE: This requires TransitionLayoutCache which will be added in Task 2
        // For now, use a simple calculation
        let pixelsPerSecond: CGFloat = 50.0
        let timeOffset = CMTime(seconds: Double(dragOffset.width / pixelsPerSecond), preferredTimescale: 600)

        var newDuration = transition.duration
        switch edge {
        case .leading:
            // Dragging left edge changes start time, which affects duration
            newDuration = CMTimeSubtract(transition.duration, timeOffset)
        case .trailing:
            // Dragging right edge changes end time
            newDuration = CMTimeAdd(transition.duration, timeOffset)
        }

        // Validate new duration
        if newDuration > TransitionValidator.minimumDuration {
            transition = transition.withDuration(newDuration)

            // Validate against clip overlap
            if let leadingClip = track.clips.first(where: { $0.id == transition.leadingClipID }),
               let trailingClip = track.clips.first(where: { $0.id == transition.trailingClipID }) {
                let validator = TransitionValidator()

                // Temporarily remove this transition from existingTransitions
                let otherTransitions = transitions.filter { $0.id != transitionID }

                do {
                    try validator.validate(transition, leadingClip: leadingClip, trailingClip: trailingClip, existingTransitions: otherTransitions)

                    // Update transition
                    updateTransition(transition)

                    // NOTE: layoutCache.invalidateTransition will be added in Task 2
                    // layoutCache.invalidateTransition(transitionID: transitionID)

                } catch {
                    // Validation failed, revert
                    print("Invalid transition duration: \(error.localizedDescription)")
                }
            }
        }

        // Clear drag state
        draggingTransitionID = nil
        draggingTransitionEdge = nil
        originalTransitionDuration = .zero
        dragOffset = .zero

        // Post notification
        NotificationCenter.default.post(
            name: .transitionDragEnded,
            object: self
        )
    }

    /// Cancels transition drag
    func cancelTransitionDrag() {
        draggingTransitionID = nil
        draggingTransitionEdge = nil
        originalTransitionDuration = .zero
        dragOffset = .zero

        // Post notification
        NotificationCenter.default.post(
            name: .transitionDragCancelled,
            object: self
        )
    }

    /// Updates a transition
    private func updateTransition(_ transition: TransitionClip) {
        if let index = transitions.firstIndex(where: { $0.id == transition.id }) {
            transitions[index] = transition
            editorState.updateTransition(transition)
        }
    }

    /// Handles transition drag gesture
    func handleTransitionDrag(transitionID: UUID, edge: TransitionEdge, offset: CGFloat) {
        guard draggingTransitionID == nil || draggingTransitionID == transitionID else {
            return
        }

        if draggingTransitionID == nil {
            // Starting new drag
            let position = CGPoint(x: offset, y: 0)
            startTransitionDrag(transitionID: transitionID, edge: edge, at: position)
        } else {
            // Continuing drag
            updateTransitionDrag(at: CGPoint(x: offset, y: 0))
        }
    }
}

// MARK: - Transition Commands

extension TimelineViewModel {
    /// Creates a transition between two clips
    func createTransition(type: TransitionType, between leadingClipID: UUID, and trailingClipID: UUID) {
        // Use TransitionFactory to create the transition
        guard let transition = TransitionFactory.createTransition(
            type: type,
            between: leadingClipID,
            and: trailingClipID,
            in: editorState
        ) else {
            print("Failed to create transition: insufficient overlap or invalid clips")
            return
        }

        editorState.addTransition(transition)
    }

    /// Deletes a transition
    func deleteTransition(_ id: UUID) {
        editorState.removeTransition(id: id)
    }

    /// Changes the type of a transition
    func changeTransitionType(_ id: UUID, to newType: TransitionType) {
        guard var transition = editorState.transitions.first(where: { $0.id == id }) else {
            return
        }

        transition = transition.withType(newType)
        editorState.updateTransition(transition)
    }
}

// MARK: - Undo/Redo

extension TimelineViewModel {
    /// Undoes the last operation
    func undo() {
        try? editorState.undo()
    }

    /// Redoes the last undone operation
    func redo() {
        try? editorState.redo()
    }
}

// MARK: - EditorState Sync

extension TimelineViewModel {
    /// Refreshes transitions from EditorState
    func syncTransitions() {
        transitions = editorState.transitions
    }
}
