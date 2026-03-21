import SwiftUI
import CoreMedia

/// SwiftUI view for the timeline root, rendering tracks and transitions
/// This serves as the main SwiftUI timeline container
struct TimelineRootView: View {
    /// The editor state that backs the timeline
    @ObservedObject var editorState: EditorState

    /// View model for timeline interactions
    @StateObject private var viewModel: TimelineViewModel

    /// Creates a new timeline root view
    /// - Parameter editorState: The editor state
    init(editorState: EditorState) {
        self.editorState = editorState
        _viewModel = StateObject(wrappedValue: TimelineViewModel(editorState: editorState))
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(spacing: 0) {
                // Render each track
                ForEach(viewModel.tracks) { track in
                    ClipTrackView(
                        track: track,
                        viewModel: viewModel,
                        selectedClipIDs: viewModel.selectedClipIDs,
                        onClipSelected: { clipID in
                            viewModel.selectClip(clipID)
                        },
                        onClipDragged: { clipID, offset in
                            // Handle clip dragging
                            // TODO: Implement clip drag handling
                        }
                    )
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .transitionsChanged)) { _ in
            viewModel.syncTransitions()
        }
    }
}
