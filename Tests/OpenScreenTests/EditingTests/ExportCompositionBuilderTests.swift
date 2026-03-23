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

    // MARK: - Quality Settings Tests

    func testBuildForExportWithDefaultQuality() async throws {
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
        // Default quality is .good (1920x1080)
        XCTAssertEqual(composition!.renderSize.width, 1920)
        XCTAssertEqual(composition!.renderSize.height, 1080)
    }

    func testBuildForExportWithDraftQuality() async throws {
        let editorState = EditorState.createTestState()

        let clips = TestDataFactory.makeOverlappingClipsSequence(count: 2)
        let track = TestDataFactory.makeTestClipTrack(clips: clips)
        editorState.clipTracks = [track]

        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: clips[0].id,
            trailingClipID: clips[1].id
        )
        editorState.addTransition(transition)

        let builder = ExportCompositionBuilder()
        let composition = try await builder.buildForExport(from: editorState, quality: .draft)

        XCTAssertNotNil(composition)
        // Draft quality is 1280x720
        XCTAssertEqual(composition!.renderSize.width, 1280)
        XCTAssertEqual(composition!.renderSize.height, 720)
    }

    func testBuildForExportWithBestQuality() async throws {
        let editorState = EditorState.createTestState()

        let clips = TestDataFactory.makeOverlappingClipsSequence(count: 2)
        let track = TestDataFactory.makeTestClipTrack(clips: clips)
        editorState.clipTracks = [track]

        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: clips[0].id,
            trailingClipID: clips[1].id
        )
        editorState.addTransition(transition)

        let builder = ExportCompositionBuilder()
        let composition = try await builder.buildForExport(from: editorState, quality: .best)

        XCTAssertNotNil(composition)
        // Best quality uses source resolution (from first clip's asset)
        // Test video is 1920x1080, so we expect that
        XCTAssertEqual(composition!.renderSize.width, 1920)
        XCTAssertEqual(composition!.renderSize.height, 1080)
    }

    func testBuildForExportWithCustomQuality() async throws {
        let editorState = EditorState.createTestState()

        let clips = TestDataFactory.makeOverlappingClipsSequence(count: 2)
        let track = TestDataFactory.makeTestClipTrack(clips: clips)
        editorState.clipTracks = [track]

        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: clips[0].id,
            trailingClipID: clips[1].id
        )
        editorState.addTransition(transition)

        // Create custom quality setting with different resolution
        let customQuality = ExportQualitySettings(
            preset: .custom,
            renderSize: CGSize(width: 2560, height: 1440),
            bitrate: 20,
            antiAliasing: .multiSample
        )

        let builder = ExportCompositionBuilder()
        let composition = try await builder.buildForExport(from: editorState, quality: customQuality)

        XCTAssertNotNil(composition)
        // Custom quality should use specified render size
        XCTAssertEqual(composition!.renderSize.width, 2560)
        XCTAssertEqual(composition!.renderSize.height, 1440)
    }
}
