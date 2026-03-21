import Foundation
import AVFoundation
import CoreMedia

/// State management for the video editor
@MainActor
final class EditorState: ObservableObject {
    static var shared: EditorState!

    private init(assetURL: URL) {
        // Private initializer to enforce singleton pattern
        self.assetURL = assetURL
    }

    static func initializeShared(with assetURL: URL) {
        shared = EditorState(assetURL: assetURL)
    }

    // Test-friendly initialization
    static func createTestState() -> EditorState {
        return EditorState(assetURL: URL(fileURLWithPath: ""))
    }
    @Published var currentTime: CMTime = .zero
    @Published var isPlaying: Bool = false
    @Published var playbackRate: Float = 1.0
    @Published var volume: Float = 1.0

    @Published var visibleTimeRange: ClosedRange<CMTime> = CMTime.zero...CMTime.zero
    @Published var zoomLevel: Double = 50.0
    @Published var tracks: [TimelineTrack] = []
    var duration: CMTime = .zero

    // MARK: - Phase 2.3 Properties

    // Loop Regions
    @Published var loopRegions: [LoopRegion] = [] {
        didSet {
            NotificationCenter.default.post(name: .loopRegionsDidChange, object: self)
        }
    }
    @Published var activeLoopRegionID: UUID? {
        didSet {
            NotificationCenter.default.post(name: .activeLoopDidChange, object: self)
        }
    }

    // Chapter Markers
    @Published var chapterMarkers: [ChapterMarker] = [] {
        didSet {
            NotificationCenter.default.post(name: .chapterMarkersDidChange, object: self)
        }
    }

    // In/Out Points
    @Published var inPoint: CMTime? {
        didSet {
            // Validate: ensure time is >= 0
            if let time = inPoint, CMTimeGetSeconds(time) < 0 {
                inPoint = nil
                return
            }
            NotificationCenter.default.post(name: .inPointDidChange, object: self)
        }
    }
    @Published var outPoint: CMTime? {
        didSet {
            // Validate: ensure time is >= 0
            if let time = outPoint, CMTimeGetSeconds(time) < 0 {
                outPoint = nil
                return
            }
            NotificationCenter.default.post(name: .outPointDidChange, object: self)
        }
    }

    // Loop Start/End (for loop control)
    var loopStart: CMTime? {
        didSet {
            NotificationCenter.default.post(name: .loopStartDidChange, object: self)
        }
    }
    var loopEnd: CMTime? {
        didSet {
            NotificationCenter.default.post(name: .loopEndDidChange, object: self)
        }
    }
    @Published var focusMode: FocusMode = .showFullTimeline {
        didSet {
            NotificationCenter.default.post(name: .focusModeDidChange, object: self)
        }
    }

    // Scrubbing State
    @Published var isScrubbing: Bool = false {
        didSet {
            NotificationCenter.default.post(name: .scrubbingStateDidChange, object: self)
        }
    }

    // Effect Stack
    @Published var effectStack: EffectStack = EffectStack() {
        didSet {
            NotificationCenter.default.post(name: .effectStackDidChange, object: self)
        }
    }

    private(set) var assetURL: URL
    var asset: AVAsset?

    // MARK: - Phase 3.0 Multi-Clip Properties

    /// Timeline edit mode for this project
    @Published var timelineEditMode: TimelineEditMode = .singleAsset {
        didSet {
            NotificationCenter.default.post(name: .timelineEditModeDidChange, object: self)
        }
    }

    /// Multi-clip tracks (only used in .multiClip mode)
    // Note: ClipTrack is used in multi-clip mode, TimelineTrack is used in single-asset mode
    @Published var clipTracks: [ClipTrack] = []

    /// Transitions between clips
    @Published var transitions: [TransitionClip] = [] {
        didSet {
            NotificationCenter.default.post(name: .transitionsChanged, object: self)
        }
    }

    /// Currently selected transition ID
    @Published var selectedTransitionID: UUID? {
        didSet {
            postSelectionChangeNotification()
        }
    }

    /// Clip operation history for undo/redo
    var clipOperations: [ClipOperation] = []
    var redoStack: [ClipOperation] = []

    // MARK: - Phase 3.0.2 Undo/Redo Properties

    /// Undo/redo manager (lazy initialization)
    private(set) var undoManager: ClipUndoManager!

    /// Initialize the undo manager (called during app startup)
    func initializeUndoManager() {
        undoManager = ClipUndoManager(editorState: self)
    }

    // MARK: - Undo/Redo Convenience Methods

    /// Undo the last operation
    func undo() throws {
        try undoManager.undo()
    }

    /// Redo the last undone operation
    func redo() throws {
        try undoManager.redo()
    }

    /// Can undo operations?
    var canUndo: Bool { undoManager?.canUndo ?? false }

    /// Can redo operations?
    var canRedo: Bool { undoManager?.canRedo ?? false }

    /// Description of operation that would be undone
    var undoDescription: String? { undoManager?.undoDescription }

    /// Description of operation that would be redone
    var redoDescription: String? { undoManager?.redoDescription }

    /// Base visible timeline duration in seconds at zoom level 1.0
    /// This represents the minimum duration that fits within the timeline view
    private static let baseVisibleDuration: Double = 800.0

    // MARK: - Computed Properties

    var activeLoopRegion: LoopRegion? {
        guard let id = activeLoopRegionID else { return nil }
        return loopRegions.first { $0.id == id }
    }

    func loadAsset(from url: URL) async throws {
        self.assetURL = url
        let asset = AVAsset(url: url)
        self.asset = asset
        self.duration = try await asset.load(.duration)
        self.currentTime = .zero

        // Initialize timeline tracks
        tracks = [
            TimelineTrack(id: UUID(), type: .video, name: "Video", height: 120),
            TimelineTrack(id: UUID(), type: .audio, name: "Audio", height: 60)
        ]
        visibleTimeRange = .zero...duration
    }

    func seek(to time: CMTime) async throws {
        guard duration != .zero else {
            throw TimelineError.videoNotLoaded
        }

        let clampedTime: CMTime
        if CMTimeGetSeconds(time) < 0 {
            clampedTime = .zero
        } else if CMTimeGetSeconds(time) > CMTimeGetSeconds(duration) {
            clampedTime = duration
        } else {
            clampedTime = time
        }

        currentTime = clampedTime

        NotificationCenter.default.post(
            name: .seekToTime,
            object: nil,
            userInfo: ["time": clampedTime]
        )
    }

    func setZoomLevel(_ newZoom: Double) async {
        zoomLevel = max(10.0, min(200.0, newZoom))

        let visibleDuration: Double = Self.baseVisibleDuration / zoomLevel
        let centerTime = CMTimeGetSeconds(currentTime)
        let halfDuration = visibleDuration / 2.0

        let newStart = max(centerTime - halfDuration, 0.0)
        let newEnd = min(centerTime + halfDuration, CMTimeGetSeconds(duration))

        visibleTimeRange = CMTime(seconds: newStart, preferredTimescale: 600)...CMTime(seconds: newEnd, preferredTimescale: 600)

        NotificationCenter.default.post(
            name: .zoomLevelDidChange,
            object: nil,
            userInfo: ["zoomLevel": zoomLevel]
        )
    }

    func togglePlayback() async {
        if isPlaying {
            await stopPlayback()
        } else {
            await startPlayback()
        }
    }

    func startPlayback() async {
        isPlaying = true
    }

    func stopPlayback() async {
        isPlaying = false
    }

    func stepForward() async {
        let frameDuration = CMTime(seconds: 1.0 / 30.0, preferredTimescale: 600)
        var newTime = CMTimeAdd(currentTime, frameDuration)

        if CMTimeGetSeconds(newTime) > CMTimeGetSeconds(duration) {
            newTime = duration
        }

        do {
            try await seek(to: newTime)
        } catch {
            // Log the error but don't fail stepping operation
            // The seek method already validates time bounds, so errors are unexpected
            print("Warning: Failed to step forward: \(error.localizedDescription)")
        }
    }

    func stepBackward() async {
        let frameDuration = CMTime(seconds: 1.0 / 30.0, preferredTimescale: 600)
        var newTime = CMTimeSubtract(currentTime, frameDuration)

        if CMTimeGetSeconds(newTime) < 0 {
            newTime = .zero
        }

        do {
            try await seek(to: newTime)
        } catch {
            // Log the error but don't fail stepping operation
            // The seek method already validates time bounds, so errors are unexpected
            print("Warning: Failed to step backward: \(error.localizedDescription)")
        }
    }
}

// MARK: - Transitions

extension EditorState {
    /// Adds a transition to the timeline
    func addTransition(_ transition: TransitionClip) {
        transitions.append(transition)
    }

    /// Removes a transition from the timeline
    func removeTransition(id: UUID) {
        transitions.removeAll { $0.id == id }
        if selectedTransitionID == id {
            selectedTransitionID = nil
        }
    }

    /// Updates an existing transition
    func updateTransition(_ transition: TransitionClip) {
        if let index = transitions.firstIndex(where: { $0.id == transition.id }) {
            transitions[index] = transition
        }
    }

    /// Finds transitions involving a specific clip
    func transitions(for clipID: UUID) -> [TransitionClip] {
        return transitions.filter {
            $0.leadingClipID == clipID || $0.trailingClipID == clipID
        }
    }

    /// Finds transition between two specific clips
    func transition(between clipID1: UUID, and clipID2: UUID) -> TransitionClip? {
        return transitions.first {
            ($0.leadingClipID == clipID1 && $0.trailingClipID == clipID2) ||
            ($0.leadingClipID == clipID2 && $0.trailingClipID == clipID1)
        }
    }

    /// Calculates the overlap between two clips
    /// - Parameters:
    ///   - clipID1: ID of the first clip
    ///   - clipID2: ID of the second clip
    /// - Returns: Time range of the overlap, or empty range if no overlap
    func calculateOverlap(between clipID1: UUID, and clipID2: UUID) -> CMTimeRange {
        // Find clips in all tracks
        guard
            let clip1 = clipTracks.flatMap({ $0.clips }).first(where: { $0.id == clipID1 }),
            let clip2 = clipTracks.flatMap({ $0.clips }).first(where: { $0.id == clipID2 })
        else {
            return CMTimeRange(start: .zero, duration: .zero)
        }

        let range1 = clip1.timeRangeInTimeline
        let range2 = clip2.timeRangeInTimeline

        // Calculate overlap
        let start = max(range1.start, range2.start)
        let end = min(range1.end, range2.end)

        guard start < end else {
            return CMTimeRange(start: .zero, duration: .zero)
        }

        return CMTimeRange(start: start, end: end)
    }

    private func postSelectionChangeNotification() {
        NotificationCenter.default.post(
            name: .transitionSelectionChanged,
            object: self,
            userInfo: ["selectedTransitionID": selectedTransitionID as Any]
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let seekToTime = Notification.Name("seekToTime")
    static let zoomLevelDidChange = Notification.Name("zoomLevelDidChange")

    // Phase 2.3 Notifications
    static let loopRegionsDidChange = Notification.Name("loopRegionsDidChange")
    static let activeLoopDidChange = Notification.Name("activeLoopDidChange")
    static let chapterMarkersDidChange = Notification.Name("chapterMarkersDidChange")
    static let inPointDidChange = Notification.Name("inPointDidChange")
    static let outPointDidChange = Notification.Name("outPointDidChange")
    static let loopStartDidChange = Notification.Name("loopStartDidChange")
    static let loopEndDidChange = Notification.Name("loopEndDidChange")
    static let focusModeDidChange = Notification.Name("focusModeDidChange")
    static let scrubbingStateDidChange = Notification.Name("scrubbingStateDidChange")
    static let effectStackDidChange = Notification.Name("effectStackDidChange")

    // Phase 3.1 Notifications
    static let transitionsChanged = Notification.Name("transitionsChanged")
    static let transitionSelectionChanged = Notification.Name("transitionSelectionChanged")
}

// MARK: - Supporting Types

enum FocusMode: Int, Codable, Sendable {
    case focusOnSelection = 0
    case showFullTimeline = 1
}
