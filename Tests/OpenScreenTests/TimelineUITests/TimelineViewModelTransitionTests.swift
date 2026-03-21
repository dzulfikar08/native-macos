import XCTest
import CoreGraphics
import CoreMedia
@testable import OpenScreen

@MainActor
final class TimelineViewModelTransitionTests: XCTestCase {
    var viewModel: TimelineViewModel!
    var editorState: EditorState!

    override func setUp() async throws {
        try await super.setUp()
        editorState = EditorState.createTestState()
        viewModel = TimelineViewModel(editorState: editorState)
    }

    // MARK: - Selection Tests

    func testSelectTransition() {
        let transition = TestDataFactory.makeTransition()
        editorState.addTransition(transition)
        viewModel.syncTransitions()

        viewModel.selectTransition(transition.id)

        XCTAssertTrue(viewModel.isTransitionSelected(transition.id))
        XCTAssertEqual(viewModel.selectedTransition?.id, transition.id)
    }

    func testDeselectTransition() {
        let transition = TestDataFactory.makeTransition()
        editorState.addTransition(transition)
        viewModel.syncTransitions()
        viewModel.selectTransition(transition.id)

        viewModel.deselectTransition()

        XCTAssertNil(viewModel.selectedTransitionID)
    }

    // MARK: - Transition Query Tests

    func testTransitionsForTrack() {
        let clip1 = TestDataFactory.makeVideoClip()
        let clip2 = TestDataFactory.makeVideoClip()
        let track = TestDataFactory.makeClipTrack(clips: [clip1, clip2])

        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: clip1.id,
            trailingClipID: clip2.id
        )

        editorState.clipTracks = [track]
        editorState.addTransition(transition)
        viewModel.syncTransitions()

        let trackTransitions = viewModel.transitions(for: track.id)

        XCTAssertEqual(trackTransitions.count, 1)
        XCTAssertEqual(trackTransitions.first?.id, transition.id)
    }

    // MARK: - Drag Tests

    func testStartTransitionDrag() {
        let transition = TestDataFactory.makeTransition()
        editorState.addTransition(transition)
        viewModel.syncTransitions()

        let position = CGPoint(x: 100, y: 30)
        viewModel.startTransitionDrag(transitionID: transition.id, edge: .trailing, at: position)

        XCTAssertEqual(viewModel.draggingTransitionID, transition.id)
        XCTAssertEqual(viewModel.draggingTransitionEdge, .trailing)
    }

    func testUpdateTransitionDrag() {
        let transition = TestDataFactory.makeTransition()
        editorState.addTransition(transition)
        viewModel.syncTransitions()

        viewModel.startTransitionDrag(transitionID: transition.id, edge: .trailing, at: .zero)

        let newPosition = CGPoint(x: 50, y: 30)
        viewModel.updateTransitionDrag(at: newPosition)

        XCTAssertNotNil(viewModel.dragOffset)
    }

    func testEndTransitionDrag() {
        let (leading, trailing, overlap) = TestDataFactory.makeOverlappingClipsWithTransition()
        let track = TestDataFactory.makeClipTrack(clips: [leading, trailing])

        editorState.clipTracks = [track]
        editorState.addTransition(overlap.transition)
        viewModel.syncTransitions()

        viewModel.startTransitionDrag(transitionID: overlap.transition.id, edge: .trailing, at: .zero)
        viewModel.updateTransitionDrag(at: CGPoint(x: 20, y: 0))

        viewModel.endTransitionDrag()

        XCTAssertNil(viewModel.draggingTransitionID)
    }

    func testCancelTransitionDrag() {
        let transition = TestDataFactory.makeTransition()
        editorState.addTransition(transition)
        viewModel.syncTransitions()

        viewModel.startTransitionDrag(transitionID: transition.id, edge: .trailing, at: .zero)
        viewModel.cancelTransitionDrag()

        XCTAssertNil(viewModel.draggingTransitionID)
        XCTAssertNil(viewModel.draggingTransitionEdge)
    }

    // MARK: - Command Tests

    func testCreateTransition() {
        let (leading, trailing, _) = TestDataFactory.makeOverlappingClips()
        let track = TestDataFactory.makeClipTrack(clips: [leading, trailing])

        editorState.clipTracks = [track]

        viewModel.createTransition(
            type: .crossfade,
            between: leading.id,
            and: trailing.id
        )

        XCTAssertNotNil(editorState.transition(between: leading.id, and: trailing.id))
    }

    func testDeleteTransition() {
        let transition = TestDataFactory.makeTransition()
        editorState.addTransition(transition)
        viewModel.syncTransitions()

        viewModel.deleteTransition(transition.id)

        XCTAssertNil(editorState.transitions.first(where: { $0.id == transition.id }))
    }

    func testChangeTransitionType() {
        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID()
        )
        editorState.addTransition(transition)
        viewModel.syncTransitions()

        viewModel.changeTransitionType(transition.id, to: .wipe)

        let modified = editorState.transitions.first(where: { $0.id == transition.id })
        XCTAssertEqual(modified?.type, .wipe)
    }

    // MARK: - Selection Interaction Tests

    func testSelectingClipDeselectsTransition() {
        let transition = TestDataFactory.makeTransition()
        let clip = TestDataFactory.makeVideoClip()

        editorState.addTransition(transition)
        viewModel.syncTransitions()
        viewModel.selectTransition(transition.id)

        XCTAssertTrue(viewModel.isTransitionSelected(transition.id))

        viewModel.selectClip(clip.id)

        XCTAssertFalse(viewModel.isTransitionSelected(transition.id))
        XCTAssertTrue(viewModel.isClipSelected(clip.id))
    }

    func testSelectingTransitionDeselectsClips() {
        let clip1 = TestDataFactory.makeVideoClip()
        let clip2 = TestDataFactory.makeVideoClip()
        let transition = TestDataFactory.makeTransition()

        editorState.addTransition(transition)
        viewModel.syncTransitions()
        viewModel.selectClips([clip1.id, clip2.id])

        XCTAssertEqual(viewModel.selectedClipIDs.count, 2)

        viewModel.selectTransition(transition.id)

        XCTAssertTrue(viewModel.selectedClipIDs.isEmpty)
        XCTAssertTrue(viewModel.isTransitionSelected(transition.id))
    }

    func testDeselectAllClearsBoth() {
        let clip = TestDataFactory.makeVideoClip()
        let transition = TestDataFactory.makeTransition()

        editorState.addTransition(transition)
        viewModel.syncTransitions()
        viewModel.selectClip(clip.id)
        viewModel.selectTransition(transition.id)

        viewModel.deselectAll()

        XCTAssertFalse(viewModel.isClipSelected(clip.id))
        XCTAssertFalse(viewModel.isTransitionSelected(transition.id))
    }
}
