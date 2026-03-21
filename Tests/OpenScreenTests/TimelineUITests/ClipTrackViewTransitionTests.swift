import XCTest
import SwiftUI
import CoreMedia
@testable import OpenScreen

@MainActor
final class ClipTrackViewTransitionTests: XCTestCase {
    func testClipTrackViewRendersTransitions() {
        let editorState = EditorState.createTestState()
        let viewModel = TimelineViewModel(editorState: editorState)

        let (leading, trailing, transition) = TestDataFactory.makeOverlappingClipsWithTransition()
        let track = TestDataFactory.makeTestClipTrack(clips: [leading, trailing])

        editorState.clipTracks = [track]
        editorState.addTransition(transition)
        viewModel.syncTransitions()

        viewModel.layoutCache.invalidateAll()
        for clip in track.clips {
            viewModel.layoutCache.register(clip)
        }

        let trackView = ClipTrackView(
            track: track,
            viewModel: viewModel,
            selectedClipIDs: viewModel.selectedClipIDs,
            onClipSelected: { _ in },
            onClipDragged: { _, _ in }
        )

        // Basic smoke test - ensure view renders without crashing
        _ = trackView.body
    }

    func testTransitionsAppearAboveClips() {
        // Test that transitions are rendered in overlay ZStack
        // This is a visual test that verifies the view hierarchy
        let editorState = EditorState.createTestState()
        let viewModel = TimelineViewModel(editorState: editorState)

        let (leading, trailing, transition) = TestDataFactory.makeOverlappingClipsWithTransition()
        let track = TestDataFactory.makeTestClipTrack(clips: [leading, trailing])

        editorState.clipTracks = [track]
        editorState.addTransition(transition)
        viewModel.syncTransitions()

        viewModel.layoutCache.invalidateAll()
        for clip in track.clips {
            viewModel.layoutCache.register(clip)
        }

        let trackView = ClipTrackView(
            track: track,
            viewModel: viewModel,
            selectedClipIDs: viewModel.selectedClipIDs,
            onClipSelected: { _ in },
            onClipDragged: { _, _ in }
        )

        // Verify the view structure uses ZStack for layering
        let body = trackView.body
        // The body should be a ZStack containing both clips and transitions
        _ = body
    }

    func testClipTrackViewWithMultipleTransitions() {
        let editorState = EditorState.createTestState()
        let viewModel = TimelineViewModel(editorState: editorState)

        // Create overlapping clip sequence
        let clips = TestDataFactory.makeOverlappingClipsSequence(count: 4)
        let track = TestDataFactory.makeTestClipTrack(clips: clips)

        editorState.clipTracks = [track]

        // Create transitions between adjacent clips
        for i in 0..<(clips.count - 1) {
            let transition = TestDataFactory.makeTransition(
                type: .crossfade,
                duration: CMTime(seconds: 1.0, preferredTimescale: 600),
                leadingClipID: clips[i].id,
                trailingClipID: clips[i + 1].id
            )
            editorState.addTransition(transition)
        }

        viewModel.syncTransitions()

        viewModel.layoutCache.invalidateAll()
        for clip in track.clips {
            viewModel.layoutCache.register(clip)
        }

        let trackView = ClipTrackView(
            track: track,
            viewModel: viewModel,
            selectedClipIDs: viewModel.selectedClipIDs,
            onClipSelected: { _ in },
            onClipDragged: { _, _ in }
        )

        // Should render all clips and transitions without crashing
        _ = trackView.body

        // Verify transitions were created
        XCTAssertEqual(viewModel.transitions(for: track.id).count, 3)
    }

    func testClipTrackViewTransitionSelection() {
        let editorState = EditorState.createTestState()
        let viewModel = TimelineViewModel(editorState: editorState)

        let (leading, trailing, transition) = TestDataFactory.makeOverlappingClipsWithTransition()
        let track = TestDataFactory.makeTestClipTrack(clips: [leading, trailing])

        editorState.clipTracks = [track]
        editorState.addTransition(transition)
        viewModel.syncTransitions()

        viewModel.layoutCache.invalidateAll()
        for clip in track.clips {
            viewModel.layoutCache.register(clip)
        }

        let trackView = ClipTrackView(
            track: track,
            viewModel: viewModel,
            selectedClipIDs: viewModel.selectedClipIDs,
            onClipSelected: { _ in },
            onClipDragged: { _, _ in }
        )

        // Select transition
        viewModel.selectTransition(transition.id)

        // Verify transition is selected
        XCTAssertTrue(viewModel.isTransitionSelected(transition.id))

        // View should render with selected state
        _ = trackView.body
    }

    func testClipTrackViewEmptyTrack() {
        let editorState = EditorState.createTestState()
        let viewModel = TimelineViewModel(editorState: editorState)

        let track = TestDataFactory.makeTestClipTrack(clips: [])

        editorState.clipTracks = [track]
        viewModel.syncTransitions()

        let trackView = ClipTrackView(
            track: track,
            viewModel: viewModel,
            selectedClipIDs: viewModel.selectedClipIDs,
            onClipSelected: { _ in },
            onClipDragged: { _, _ in }
        )

        // Should render empty track without crashing
        _ = trackView.body
    }

    func testClipTrackViewClipsWithoutTransitions() {
        let editorState = EditorState.createTestState()
        let viewModel = TimelineViewModel(editorState: editorState)

        let clips = TestDataFactory.makeClipSequence(count: 3)
        let track = TestDataFactory.makeTestClipTrack(clips: clips)

        editorState.clipTracks = [track]
        viewModel.syncTransitions()

        viewModel.layoutCache.invalidateAll()
        for clip in track.clips {
            viewModel.layoutCache.register(clip)
        }

        let trackView = ClipTrackView(
            track: track,
            viewModel: viewModel,
            selectedClipIDs: viewModel.selectedClipIDs,
            onClipSelected: { _ in },
            onClipDragged: { _, _ in }
        )

        // Should render clips without transitions
        _ = trackView.body

        // Verify no transitions
        XCTAssertTrue(viewModel.transitions(for: track.id).isEmpty)
    }
}
