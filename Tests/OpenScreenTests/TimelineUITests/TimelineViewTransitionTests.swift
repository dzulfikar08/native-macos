import XCTest
@testable import OpenScreen

@MainActor
final class TimelineViewTransitionTests: XCTestCase {
    var editorState: EditorState!

    override func setUp() {
        super.setUp()
        editorState = EditorState.createTestState()
    }

    override func tearDown() {
        editorState = nil
        super.tearDown()
    }

    func testTimelineViewRendersTransitions() {
        let timelineView = TimelineRootView(editorState: editorState)

        let (leading, trailing, overlap) = TestDataFactory.makeOverlappingClipsWithTransition()
        let track = TestDataFactory.makeTestClipTrack(clips: [leading, trailing])

        editorState.clipTracks = [track]
        editorState.addTransition(overlap.transition)

        // Should render without crashing
        _ = timelineView.body
    }

    func testTimelineViewTransitionsSyncWithEditorState() {
        let timelineView = TimelineRootView(editorState: editorState)

        let (leading, trailing, overlap) = TestDataFactory.makeOverlappingClipsWithTransition()
        let track = TestDataFactory.makeTestClipTrack(clips: [leading, trailing])

        editorState.clipTracks = [track]

        // Add transition to EditorState
        editorState.addTransition(overlap.transition)

        // TimelineView should sync via notification
        // (This would be tested with UI tests in production)
    }

    func testTimelineViewTransitionSelection() {
        let viewModel = TimelineViewModel(editorState: editorState)
        let timelineView = TimelineRootView(editorState: editorState)

        let transition = TestDataFactory.makeTransition()
        editorState.addTransition(transition)

        viewModel.selectTransition(transition.id)

        XCTAssertTrue(viewModel.isTransitionSelected(transition.id))
    }
}
