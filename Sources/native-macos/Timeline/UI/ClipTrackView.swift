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

    var body: some View {
        ZStack {
            // Existing clips rendering
            clipsLayer

            // Transitions overlay
            transitionsOverlay
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
}
