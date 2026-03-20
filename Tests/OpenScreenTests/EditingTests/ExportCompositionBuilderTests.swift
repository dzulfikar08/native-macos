import XCTest
import AVFoundation
import CoreMedia
@testable import OpenScreen

/// Tests for ExportCompositionBuilder
@MainActor
final class ExportCompositionBuilderTests: XCTestCase {

    func testBuildExportComposition() async throws {
        let editorState = EditorState.createTestState()

        let clips = TestDataFactory.makeOverlappingClipsSequence(count: 2)
        let track = TestDataFactory.makeTestClipTrack(clips: clips)
        editorState.clipTracks = [track]

        // Add transition
        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: clips[0].id,
            trailingClipID: clips[1].id
        )
        editorState.addTransition(transition)

        let builder = ExportCompositionBuilder()
        let composition = try await builder.buildForExport(from: editorState)

        XCTAssertNotNil(composition)
        XCTAssertGreaterThan(composition!.instructions.count, 0)
    }

    func testBuildExportCompositionNoVideoTracks() async throws {
        let editorState = EditorState.createTestState()
        // Don't add any clips or tracks

        let builder = ExportCompositionBuilder()

        await XCTAssertThrowsError(
            try await builder.buildForExport(from: editorState)
        ) { error in
            XCTAssertEqual(error as? ExportError, ExportError.noVideoTracks)
        }
    }

    func testBuildExportCompositionNoClips() async throws {
        let editorState = EditorState.createTestState()

        // Add an empty track
        let emptyTrack = TestDataFactory.makeTestClipTrack(clips: [])
        editorState.clipTracks = [emptyTrack]

        let builder = ExportCompositionBuilder()

        await XCTAssertThrowsError(
            try await builder.buildForExport(from: editorState)
        ) { error in
            XCTAssertEqual(error as? ExportError, ExportError.noVideoTracks)
        }
    }

    func testBuildExportCompositionNoTransitions() async throws {
        let editorState = EditorState.createTestState()

        // Add clips without overlap (no transitions possible)
        let clips = TestDataFactory.makeClipSequence(count: 2)
        let track = TestDataFactory.makeTestClipTrack(clips: clips)
        editorState.clipTracks = [track]

        let builder = ExportCompositionBuilder()
        let composition = try await builder.buildForExport(from: editorState)

        XCTAssertNotNil(composition)
        XCTAssertGreaterThan(composition!.instructions.count, 0)
    }

    func testBuildExportCompositionSingleClip() async throws {
        let editorState = EditorState.createTestState()

        // Add a single clip without transitions
        let clips = TestDataFactory.makeClipSequence(count: 1)
        let track = TestDataFactory.makeTestClipTrack(clips: clips)
        editorState.clipTracks = [track]

        let builder = ExportCompositionBuilder()
        let composition = try await builder.buildForExport(from: editorState)

        // Single clip should still generate a valid composition
        XCTAssertNotNil(composition)
        XCTAssertGreaterThan(composition!.instructions.count, 0)
    }
}
