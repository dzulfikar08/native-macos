import SwiftUI
import CoreMedia

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

    var body: some View {
        ZStack {
            // Existing clips rendering
            clipsLayer

            // Transitions overlay
            transitionsOverlay
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
