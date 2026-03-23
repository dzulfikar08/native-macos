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

    // MARK: - Quality Settings Tests

    func testExportWithDefaultQuality() async throws {
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

        let pipeline = TransitionExportPipeline(editorState: editorState)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_default_quality_\(UUID().uuidString).mov")

        // Export with default quality (.good)
        try await pipeline.export(to: outputURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))

        // Clean up
        try? FileManager.default.removeItem(at: outputURL)
    }

    func testExportWithDraftQuality() async throws {
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

        let pipeline = TransitionExportPipeline(editorState: editorState)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_draft_quality_\(UUID().uuidString).mov")

        // Export with draft quality
        try await pipeline.export(to: outputURL, quality: .draft)

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))

        // Clean up
        try? FileManager.default.removeItem(at: outputURL)
    }

    func testExportWithBestQuality() async throws {
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

        let pipeline = TransitionExportPipeline(editorState: editorState)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_best_quality_\(UUID().uuidString).mov")

        // Export with best quality
        try await pipeline.export(to: outputURL, quality: .best)

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))

        // Clean up
        try? FileManager.default.removeItem(at: outputURL)
    }

    // MARK: - Validation Tests

    func testValidateTransitionsPasses() async throws {
        let editorState = EditorState.createTestState()

        // Create timeline with valid transitions
        let clips = try TestDataFactory.makeOverlappingClipsSequence(count: 2)
        let track = TestDataFactory.makeTestClipTrack(clips: clips)
        editorState.clipTracks = [track]

        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: clips[0].id,
            trailingClipID: clips[1].id,
            isEnabled: true
        )
        editorState.addTransition(transition)

        let pipeline = TransitionExportPipeline(editorState: editorState)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_validation_passes_\(UUID().uuidString).mov")

        // Should succeed - both clips exist
        try await pipeline.export(to: outputURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))

        // Clean up
        try? FileManager.default.removeItem(at: outputURL)
    }

    func testValidateTransitionsFailsWithMissingLeadingClip() async throws {
        let editorState = EditorState.createTestState()

        // Create timeline with only trailing clip
        let clips = try TestDataFactory.makeOverlappingClipsSequence(count: 1)
        let track = TestDataFactory.makeTestClipTrack(clips: clips)
        editorState.clipTracks = [track]

        // Create transition with non-existent leading clip
        let fakeLeadingID = UUID()
        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: fakeLeadingID,
            trailingClipID: clips[0].id,
            isEnabled: true
        )
        editorState.addTransition(transition)

        let pipeline = TransitionExportPipeline(editorState: editorState)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_missing_leading_\(UUID().uuidString).mov")

        // Should fail - leading clip doesn't exist
        do {
            try await pipeline.export(to: outputURL)
            XCTFail("Should throw TransitionError.clipsNotFound")
        } catch TransitionError.clipsNotFound(let leadingID, let trailingID) {
            XCTAssertEqual(leadingID, fakeLeadingID)
            XCTAssertEqual(trailingID, clips[0].id)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        // Clean up if file was created
        try? FileManager.default.removeItem(at: outputURL)
    }

    func testValidateTransitionsFailsWithMissingTrailingClip() async throws {
        let editorState = EditorState.createTestState()

        // Create timeline with only leading clip
        let clips = try TestDataFactory.makeOverlappingClipsSequence(count: 1)
        let track = TestDataFactory.makeTestClipTrack(clips: clips)
        editorState.clipTracks = [track]

        // Create transition with non-existent trailing clip
        let fakeTrailingID = UUID()
        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: clips[0].id,
            trailingClipID: fakeTrailingID,
            isEnabled: true
        )
        editorState.addTransition(transition)

        let pipeline = TransitionExportPipeline(editorState: editorState)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_missing_trailing_\(UUID().uuidString).mov")

        // Should fail - trailing clip doesn't exist
        do {
            try await pipeline.export(to: outputURL)
            XCTFail("Should throw TransitionError.clipsNotFound")
        } catch TransitionError.clipsNotFound(let leadingID, let trailingID) {
            XCTAssertEqual(leadingID, clips[0].id)
            XCTAssertEqual(trailingID, fakeTrailingID)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        // Clean up if file was created
        try? FileManager.default.removeItem(at: outputURL)
    }

    func testValidateTransitionsSkipsDisabledTransitions() async throws {
        let editorState = EditorState.createTestState()

        // Create timeline with clips
        let clips = try TestDataFactory.makeOverlappingClipsSequence(count: 1)
        let track = TestDataFactory.makeTestClipTrack(clips: clips)
        editorState.clipTracks = [track]

        // Create disabled transition with missing clip
        let fakeTrailingID = UUID()
        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: clips[0].id,
            trailingClipID: fakeTrailingID,
            isEnabled: false // Disabled
        )
        editorState.addTransition(transition)

        let pipeline = TransitionExportPipeline(editorState: editorState)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_disabled_transition_\(UUID().uuidString).mov")

        // Should succeed - disabled transitions are not validated
        try await pipeline.export(to: outputURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))

        // Clean up
        try? FileManager.default.removeItem(at: outputURL)
    }

    // MARK: - AVAsset Building Tests

    func testBuildAVAssetCreatesComposition() async throws {
        let editorState = EditorState.createTestState()

        // Create timeline with multiple clips
        let clips = try TestDataFactory.makeOverlappingClipsSequence(count: 3)
        let track = TestDataFactory.makeTestClipTrack(clips: clips)
        editorState.clipTracks = [track]

        let pipeline = TransitionExportPipeline(editorState: editorState)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_build_asset_\(UUID().uuidString).mov")

        // Should build AVAsset from clips and export
        try await pipeline.export(to: outputURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))

        // Clean up
        try? FileManager.default.removeItem(at: outputURL)
    }

    // MARK: - Error Handling Tests

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

    func testExportFailsWithEmptyTimeline() async throws {
        let editorState = EditorState.createTestState()
        editorState.clipTracks = []

        let pipeline = TransitionExportPipeline(editorState: editorState)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_empty_timeline_\(UUID().uuidString).mov")

        do {
            try await pipeline.export(to: outputURL)
            XCTFail("Should throw error with empty timeline")
        } catch {
            // Expected error - no video tracks
        }

        // Clean up if file was created
        try? FileManager.default.removeItem(at: outputURL)
    }
}
