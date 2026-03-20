import XCTest
import AVFoundation
import CoreMedia
@testable import OpenScreen

/// Tests for TransitionExportPipeline end-to-end export with transitions
@MainActor
final class TransitionExportPipelineTests: XCTestCase {

    // MARK: - Export With Transitions Tests

    func testExportVideoWithTransitions() async throws {
        let editorState = EditorState.createTestState()

        // Create timeline with transitions
        let clips = try TestDataFactory.makeOverlappingClipsSequence(count: 2)
        let track = TestDataFactory.makeTestClipTrack(clips: clips)
        editorState.clipTracks = [track]

        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: clips[0].id,
            trailingClipID: clips[1].id
        )
        editorState.addTransition(transition)

        // Build export pipeline
        let pipeline = TransitionExportPipeline(editorState: editorState)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_with_transition_\(UUID().uuidString).mov")

        try await pipeline.export(to: outputURL)

        // Verify output file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))

        // Clean up
        try? FileManager.default.removeItem(at: outputURL)
    }

    func testExportMultipleTransitionTypes() async throws {
        let editorState = EditorState.createTestState()

        // Create timeline with multiple transitions
        let clips = try TestDataFactory.makeOverlappingClipsSequence(count: 4)
        let track = TestDataFactory.makeTestClipTrack(clips: clips)
        editorState.clipTracks = [track]

        // Add different transition types
        let types: [TransitionType] = [.crossfade, .wipe, .iris]
        for i in 0..<min(3, clips.count - 1) {
            let transition = TransitionClip(
                type: types[i % types.count],
                duration: CMTime(seconds: 0.5, preferredTimescale: 600),
                leadingClipID: clips[i].id,
                trailingClipID: clips[i + 1].id
            )
            editorState.addTransition(transition)
        }

        let pipeline = TransitionExportPipeline(editorState: editorState)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_multiple_transitions_\(UUID().uuidString).mov")

        try await pipeline.export(to: outputURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))

        // Clean up
        try? FileManager.default.removeItem(at: outputURL)
    }

    // MARK: - Error Handling Tests

    func testExportFailsWithoutAsset() async throws {
        let editorState = EditorState()

        let pipeline = TransitionExportPipeline(editorState: editorState)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_no_asset_\(UUID().uuidString).mov")

        do {
            try await pipeline.export(to: outputURL)
            XCTFail("Should throw error without asset")
        } catch {
            // Expected error
        }

        // Clean up if file was created
        try? FileManager.default.removeItem(at: outputURL)
    }

    func testExportWithNoTransitions() async throws {
        let editorState = EditorState.createTestState()

        // Create timeline without transitions
        let clips = try TestDataFactory.makeOverlappingClipsSequence(count: 2)
        let track = TestDataFactory.makeTestClipTrack(clips: clips)
        editorState.clipTracks = [track]

        let pipeline = TransitionExportPipeline(editorState: editorState)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_no_transitions_\(UUID().uuidString).mov")

        // Should still succeed - exports without transitions
        try await pipeline.export(to: outputURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))

        // Clean up
        try? FileManager.default.removeItem(at: outputURL)
    }
}
