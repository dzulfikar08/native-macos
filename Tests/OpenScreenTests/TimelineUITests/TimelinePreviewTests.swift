import XCTest
import SwiftUI
import CoreMedia
import AVFoundation
@testable import OpenScreen

@MainActor
final class TimelinePreviewTests: XCTestCase {
    var viewModel: TimelineViewModel!
    var editorState: EditorState!

    override func setUp() async throws {
        try await super.setUp()

        editorState = EditorState.createTestState()
        viewModel = TimelineViewModel(editorState: editorState)
    }

    // MARK: - Preview Composition Tests

    func testPreviewCompositionIncludesTransitions() async throws {
        let (leading, trailing, _) = TestDataFactory.makeOverlappingClips()
        let track = TestDataFactory.makeTestClipTrack(clips: [leading, trailing])
        editorState.clipTracks = [track]

        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: leading.id,
            trailingClipID: trailing.id
        )
        editorState.addTransition(transition)
        viewModel.syncTransitions()

        let composition = try await viewModel.buildPreviewComposition()

        XCTAssertNotNil(composition)
        XCTAssertEqual(composition?.instructions.count, 3) // clip, transition, clip
    }

    func testPreviewCompositionUpdatesAfterTransitionChange() async throws {
        let (leading, trailing, _) = TestDataFactory.makeOverlappingClips()
        let track = TestDataFactory.makeTestClipTrack(clips: [leading, trailing])
        editorState.clipTracks = [track]

        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: leading.id,
            trailingClipID: trailing.id
        )
        editorState.addTransition(transition)
        viewModel.syncTransitions()

        let composition1 = try await viewModel.buildPreviewComposition()
        XCTAssertEqual(composition1?.instructions.count, 3)

        // Change transition type
        viewModel.changeTransitionType(transition.id, to: .wipe)

        let composition2 = try await viewModel.buildPreviewComposition()
        XCTAssertNotNil(composition2)
    }
}
