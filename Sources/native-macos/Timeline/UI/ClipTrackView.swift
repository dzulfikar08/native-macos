import SwiftUI
import CoreMedia
import AppKit

/// SwiftUI view for rendering a clip track with clips and transitions overlay
struct ClipTrackView: View {
    /// The track to display
    let track: ClipTrack

    /// View model for timeline state and interactions
    @ObservedObject var viewModel: TimelineViewModel

    /// Currently selected clip IDs
    var selectedClipIDs: Set<UUID>

    /// Action when a clip is selected
    var onClipSelected: (UUID) -> Void

    /// Action when a clip is dragged
    var onClipDragged: (UUID, CGSize) -> Void

    /// State for context menu click location
    @State private var contextMenuClickLocation: CGPoint = .zero

    /// State for showing transition creation alert
    @State private var transitionAlertMessage: String?

    /// State for auto-transition prompt
    @State private var showAutoTransitionPrompt: Bool = false

    /// Detected overlap for auto-prompt
    @State private var detectedOverlap: ClipOverlap?

    /// Timestamp when auto-prompt was last dismissed (for cooldown)
    @State private var lastPromptDismissTime: Date?

    /// Cooldown duration: 5 minutes
    private let promptCooldown: TimeInterval = 5 * 60

    /// Minimum overlap for prompt: 0.5 seconds
    private let minimumPromptOverlap: CMTime = CMTime(seconds: 0.5, preferredTimescale: 600)

    var body: some View {
        ZStack {
            // Existing clips rendering
            clipsLayer

            // Transitions overlay
            transitionsOverlay

            // Auto-transition prompt overlay
            if showAutoTransitionPrompt, let overlap = detectedOverlap {
                autoTransitionPromptOverlay(for: overlap)
            }
        }
        .contextMenu {
            createTransitionSubmenu()
        }
        .alert("Transition Creation", isPresented: .constant(transitionAlertMessage != nil), presenting: transitionAlertMessage) { _ in
            Button("OK") {
                transitionAlertMessage = nil
            }
        } message: { message in
            Text(message)
        }
        .onAppear {
            // Check for overlaps when view appears
            checkForOverlapPrompt()
        }
        .onChange(of: track.clips.count) { _ in
            // Check for overlaps when clips change
            checkForOverlapPrompt()
        }
    }

    // MARK: - Clips Layer

    @ViewBuilder
    private var clipsLayer: some View {
        ForEach(track.clips) { clip in
            if let layout = viewModel.layoutCache.layout(for: clip.id) {
                clipView(for: clip, layout: layout)
            }
        }
    }

    @ViewBuilder
    private func clipView(for clip: VideoClip, layout: ClipLayout) -> some View {
        // Basic clip rendering
        RoundedRectangle(cornerRadius: 4)
            .fill(clipColor(for: clip))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(
                        selectedClipIDs.contains(clip.id) ? Color.cyan : Color.clear,
                        lineWidth: 2
                    )
            )
            .frame(width: layout.frame.width, height: layout.frame.height)
            .position(x: layout.frame.midX, y: layout.frame.midY)
            .onTapGesture {
                onClipSelected(clip.id)
            }
    }

    // MARK: - Transitions Overlay

    @ViewBuilder
    private var transitionsOverlay: some View {
        ForEach(viewModel.transitions(for: track.id), id: \.id) { transition in
            if let frame = viewModel.transitionLayoutCache.transitionFrame(
                for: transition,
                in: track,
                clipLayoutCache: viewModel.layoutCache
            ) {
                GeometryReader { geometry in
                    TransitionView(
                        transition: transition,
                        isSelected: viewModel.isTransitionSelected(transition.id),
                        showHandles: viewModel.draggingTransitionID == transition.id,
                        leadingHandleFrame: viewModel.transitionLayoutCache.dragHandleFrame(
                            for: transition,
                            edge: .leading,
                            in: track,
                            clipLayoutCache: viewModel.layoutCache
                        ) ?? .zero,
                        trailingHandleFrame: viewModel.transitionLayoutCache.dragHandleFrame(
                            for: transition,
                            edge: .trailing,
                            in: track,
                            clipLayoutCache: viewModel.layoutCache
                        ) ?? .zero,
                        onTap: {
                            viewModel.selectTransition(transition.id)
                        },
                        onLeadingHandleDrag: { offset in
                            viewModel.handleTransitionDrag(transitionID: transition.id, edge: .leading, offset: offset)
                        },
                        onTrailingHandleDrag: { offset in
                            viewModel.handleTransitionDrag(transitionID: transition.id, edge: .trailing, offset: offset)
                        }
                    )
                    .position(x: frame.midX, y: frame.midY)
                    .frame(width: frame.width, height: frame.height)
                }
            }
        }
    }

    // MARK: - Helper Properties

    private func clipColor(for clip: VideoClip) -> Color {
        // Generate a consistent color based on clip ID
        let hash = clip.id.uuidString.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.8)
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func createTransitionSubmenu() -> some View {
        Menu("Add Transition") {
            ForEach(BuiltInPresets.presets) { preset in
                Button("\(preset.name) (\(formatDuration(preset.duration)))") {
                    applyPresetFromMenu(preset)
                }
            }
        }
    }

    private func applyPresetFromMenu(_ preset: TransitionPreset) {
        // Find overlapping clips in track
        guard let (leadingClip, trailingClip) = findOverlappingClips(in: track) else {
            transitionAlertMessage = "Can only add transitions between two overlapping clips"
            return
        }

        // Validate overlap
        let overlapDuration = calculateOverlap(leading: leadingClip, trailing: trailingClip)
        guard overlapDuration >= TransitionValidator.minimumDuration else {
            transitionAlertMessage = "Clips must overlap by at least \(formatDuration(TransitionValidator.minimumDuration))"
            return
        }

        // Check if transition already exists
        if viewModel.transition(between: leadingClip.id, and: trailingClip.id) != nil {
            transitionAlertMessage = "Transition already exists between these clips"
            return
        }

        // Create transition from preset
        let transition = preset.makeTransition(
            leadingClipID: leadingClip.id,
            trailingClipID: trailingClip.id
        )

        // Add to EditorState
        viewModel.editorState.addTransition(transition)

        // Select the newly created transition
        viewModel.selectTransition(transition.id)

        // Note: Inspector opening will be handled by a separate coordinator
        // For now, the transition is created and selected
    }

    // MARK: - Auto-Transition Prompt

    /// Checks if auto-transition prompt should be shown
    private func shouldShowAutoPrompt() -> Bool {
        // Check cooldown
        if let lastDismiss = lastPromptDismissTime {
            let timeSinceDismiss = Date().timeIntervalSince(lastDismiss)
            if timeSinceDismiss < promptCooldown {
                return false
            }
        }

        // Find overlapping clips
        guard let overlap = findFirstOverlap() else {
            return false
        }

        // Check overlap duration (minimum 0.5 seconds)
        guard overlap.overlapDuration >= minimumPromptOverlap else {
            return false
        }

        // Check if transition already exists
        if viewModel.transition(between: overlap.leadingClip.id, and: overlap.trailingClip.id) != nil {
            return false
        }

        return true
    }

    /// Finds the first overlapping clip pair in the track
    private func findFirstOverlap() -> ClipOverlap? {
        let detector = ClipOverlapDetector()
        let overlaps = detector.detectOverlaps(clips: track.clips)
        return overlaps.first
    }

    /// Checks for overlaps and shows prompt if conditions are met
    func checkForOverlapPrompt() {
        guard shouldShowAutoPrompt() else {
            return
        }

        guard let overlap = findFirstOverlap() else {
            return
        }

        detectedOverlap = overlap
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showAutoTransitionPrompt = true
        }
    }

    /// Shows the auto-transition prompt
    func showAutoPrompt() {
        guard let overlap = findFirstOverlap() else {
            return
        }

        detectedOverlap = overlap
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showAutoTransitionPrompt = true
        }
    }

    /// Hides the auto-transition prompt
    func hideAutoPrompt() {
        withAnimation(.easeOut(duration: 0.2)) {
            showAutoTransitionPrompt = false
        }
        lastPromptDismissTime = Date()
        detectedOverlap = nil
    }

    /// Applies default transition (Quick Dissolve)
    func applyDefaultTransition() {
        guard let overlap = detectedOverlap else {
            return
        }

        // Create Quick Dissolve transition
        let quickDissolve = BuiltInPresets.presets.first { $0.name == "Quick Dissolve" }
        guard let preset = quickDissolve else {
            return
        }

        let transition = preset.makeTransition(
            leadingClipID: overlap.leadingClip.id,
            trailingClipID: overlap.trailingClip.id
        )

        // Add to EditorState
        viewModel.editorState.addTransition(transition)

        // Select the newly created transition
        viewModel.selectTransition(transition.id)

        // Hide prompt
        hideAutoPrompt()
    }

    /// Auto-transition prompt overlay view
    @ViewBuilder
    private func autoTransitionPromptOverlay(for overlap: ClipOverlap) -> some View {
        GeometryReader { geometry in
            // Calculate position: 60px above overlap zone
            let overlapCenter = overlap.centerPoint
            // TODO: Convert CMTime to x-position using timeline's pixels-per-second
            // For now, center horizontally in visible area
            let xPosition = geometry.size.width / 2
            let yPosition: CGFloat = -60 // 60px above track

            AutoTransitionPrompt(
                overlap: overlap,
                onApplyDissolve: {
                    applyDefaultTransition()
                },
                onDismiss: {
                    hideAutoPrompt()
                }
            )
            .position(x: xPosition, y: yPosition)
            .transition(.scale.combined(with: .opacity))
        }
    }
}

// MARK: - Context Menu Helpers

/// Finds the first pair of overlapping clips in a track
/// - Parameter track: The track to search in
/// - Returns: Tuple of (leadingClip, trailingClip) if overlapping clips exist
@MainActor
private func findOverlappingClips(in track: ClipTrack) -> (VideoClip, VideoClip)? {
    let sortedClips = track.clips.sorted { $0.timeRangeInTimeline.start < $1.timeRangeInTimeline.start }

    // Find adjacent overlapping clips
    for i in 0..<(sortedClips.count - 1) {
        let leading = sortedClips[i]
        let trailing = sortedClips[i + 1]

        let overlap = calculateOverlap(leading: leading, trailing: trailing)
        if overlap > .zero {
            return (leading, trailing)
        }
    }

    return nil
}
