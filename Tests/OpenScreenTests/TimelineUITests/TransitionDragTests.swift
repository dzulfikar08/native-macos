import XCTest
import CoreGraphics
@testable import OpenScreen

@MainActor
final class TransitionDragTests: XCTestCase {
    var viewModel: TimelineViewModel!
    var editorState: EditorState!

    override func setUp() async throws {
        try await super.setUp()
        editorState = EditorState.createTestState()
        viewModel = TimelineViewModel(editorState: editorState)
    }

    func testTransitionDragGestureLeadingEdge() {
        let (leading, trailing, overlap) = TestDataFactory.makeOverlappingClipsWithTransition()
        let track = TestDataFactory.makeTestClipTrack(clips: [leading, trailing])

        editorState.clipTracks = [track]
        editorState.addTransition(overlap.transition)
        viewModel.syncTransitions()

        // Simulate drag gesture
        viewModel.handleTransitionDrag(transitionID: overlap.transition.id, edge: .leading, offset: -10)

        XCTAssertEqual(viewModel.draggingTransitionID, overlap.transition.id)
        XCTAssertEqual(viewModel.draggingTransitionEdge, .leading)
    }

    func testTransitionDragGestureTrailingEdge() {
        let (leading, trailing, overlap) = TestDataFactory.makeOverlappingClipsWithTransition()
        let track = TestDataFactory.makeTestClipTrack(clips: [leading, trailing])

        editorState.clipTracks = [track]
        editorState.addTransition(overlap.transition)
        viewModel.syncTransitions()

        // Simulate drag gesture
        viewModel.handleTransitionDrag(transitionID: overlap.transition.id, edge: .trailing, offset: 10)

        XCTAssertEqual(viewModel.draggingTransitionID, overlap.transition.id)
        XCTAssertEqual(viewModel.draggingTransitionEdge, .trailing)
    }

    func testTransitionDragGestureCannotStartWhenDraggingClip() {
        let transition = TestDataFactory.makeTransition()
        editorState.addTransition(transition)
        viewModel.syncTransitions()

        // Note: Clip dragging functionality not yet implemented
        // This test verifies that transition drag can still start
        // Future implementation should prevent concurrent dragging

        // Simulate transition drag
        viewModel.handleTransitionDrag(transitionID: transition.id, edge: .trailing, offset: 10)

        // For now, transition drag should start normally
        XCTAssertEqual(viewModel.draggingTransitionID, transition.id)
        XCTAssertEqual(viewModel.draggingTransitionEdge, .trailing)
    }
}
