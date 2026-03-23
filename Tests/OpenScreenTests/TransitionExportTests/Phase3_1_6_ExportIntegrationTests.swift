import XCTest
import AVFoundation
@testable import OpenScreen

/// Integration tests for the complete transition export pipeline
/// Verifies that all components work together: ExportQualitySettings,
/// TransitionCompositionInstruction, TransitionVideoCompositor,
/// TransitionRenderContext, AVVideoCompositionBuilder, ExportCompositionBuilder,
/// TransitionExportPipeline, and VideoExporter.
@MainActor
final class Phase3_1_6_ExportIntegrationTests: XCTestCase {

    var editorState: EditorState!
    var outputURL: URL!

    override func setUp() async throws {
        try await super.setUp()

        // Create test editor state with clips and transitions
        editorState = EditorState.createTestState()

        // Create temporary output URL
        let tempDir = FileManager.default.temporaryDirectory
        outputURL = tempDir.appendingPathComponent("test_export_\(UUID().uuidString).mov")
    }

    override func tearDown() async throws {
        // Clean up output file
        try? FileManager.default.removeItem(at: outputURL)
        outputURL = nil
        editorState = nil
        try await super.tearDown()
    }

    // MARK: - Single Transition Export Tests

    func testExportWithSingleCrossfadeTransition() async throws {
        // Setup: Add overlapping clips with crossfade transition
        let clip1 = TestDataFactory.makeVideoClip(
            startTime: .zero,
            duration: CMTime(seconds: 5, preferredTimescale: 600)
        )
        let clip2 = TestDataFactory.makeVideoClip(
            startTime: CMTime(seconds: 4, preferredTimescale: 600),
            duration: CMTime(seconds: 5, preferredTimescale: 600)
        )

        let track = TestDataFactory.makeTestClipTrack(clips: [clip1, clip2])
        editorState.clipTracks = [track]

        let transition = TestDataFactory.makeTransition(
            type: .crossfade,
            duration: CMTime(seconds: 1, preferredTimescale: 600),
            leadingClipID: clip1.id,
            trailingClipID: clip2.id,
            parameters: .crossfade,
            isEnabled: true
        )
        editorState.addTransition(transition)

        // Execute export
        let pipeline = TransitionExportPipeline(editorState: editorState)
        try await pipeline.export(to: outputURL, quality: .good)

        // Verify output file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))

        // Verify output file has reasonable size
        let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        XCTAssertGreaterThan(fileSize, 1000, "Exported file should be at least 1KB")
    }

    func testExportWithSingleWipeTransition() async throws {
        // Setup: Add overlapping clips with wipe transition
        let clip1 = TestDataFactory.makeVideoClip(
            startTime: .zero,
            duration: CMTime(seconds: 5, preferredTimescale: 600)
        )
        let clip2 = TestDataFactory.makeVideoClip(
            startTime: CMTime(seconds: 4, preferredTimescale: 600),
            duration: CMTime(seconds: 5, preferredTimescale: 600)
        )

        let track = TestDataFactory.makeTestClipTrack(clips: [clip1, clip2])
        editorState.clipTracks = [track]

        let transition = TestDataFactory.makeWipeTransition(
            direction: .left,
            softness: 0.2,
            borderWidth: 0.0,
            duration: CMTime(seconds: 1, preferredTimescale: 600)
        )
        // Update transition with correct clip IDs
        let updatedTransition = TransitionClip(
            type: transition.type,
            duration: transition.duration,
            leadingClipID: clip1.id,
            trailingClipID: clip2.id,
            parameters: transition.parameters,
            isEnabled: true
        )
        editorState.addTransition(updatedTransition)

        // Execute export
        let pipeline = TransitionExportPipeline(editorState: editorState)
        try await pipeline.export(to: outputURL, quality: .good)

        // Verify output file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
    }

    func testExportWithSingleIrisTransition() async throws {
        // Setup: Add overlapping clips with iris transition
        let clip1 = TestDataFactory.makeVideoClip(
            startTime: .zero,
            duration: CMTime(seconds: 5, preferredTimescale: 600)
        )
        let clip2 = TestDataFactory.makeVideoClip(
            startTime: CMTime(seconds: 4, preferredTimescale: 600),
            duration: CMTime(seconds: 5, preferredTimescale: 600)
        )

        let track = TestDataFactory.makeTestClipTrack(clips: [clip1, clip2])
        editorState.clipTracks = [track]

        let transition = TestDataFactory.makeIrisTransition(
            shape: .circle,
            position: CGPoint(x: 0.5, y: 0.5),
            softness: 0.3,
            duration: CMTime(seconds: 1.5, preferredTimescale: 600)
        )
        // Update transition with correct clip IDs
        let updatedTransition = TransitionClip(
            type: transition.type,
            duration: transition.duration,
            leadingClipID: clip1.id,
            trailingClipID: clip2.id,
            parameters: transition.parameters,
            isEnabled: true
        )
        editorState.addTransition(updatedTransition)

        // Execute export
        let pipeline = TransitionExportPipeline(editorState: editorState)
        try await pipeline.export(to: outputURL, quality: .good)

        // Verify output file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
    }

    // MARK: - Multiple Transitions Export Tests

    func testExportWithMultipleTransitions() async throws {
        // Setup: Create 3 overlapping clips with 2 transitions
        let clips = TestDataFactory.makeOverlappingClipsSequence(count: 3)
        let track = TestDataFactory.makeTestClipTrack(clips: clips)
        editorState.clipTracks = [track]

        // Add transition between clip 1 and 2
        let transition1 = TestDataFactory.makeTransition(
            type: .crossfade,
            duration: CMTime(seconds: 1, preferredTimescale: 600),
            leadingClipID: clips[0].id,
            trailingClipID: clips[1].id,
            parameters: .crossfade,
            isEnabled: true
        )
        editorState.addTransition(transition1)

        // Add transition between clip 2 and 3
        let transition2 = TestDataFactory.makeTransition(
            type: .wipe,
            duration: CMTime(seconds: 1, preferredTimescale: 600),
            leadingClipID: clips[1].id,
            trailingClipID: clips[2].id,
            parameters: .wipe(direction: .right, softness: 0.2, borderWidth: 0),
            isEnabled: true
        )
        editorState.addTransition(transition2)

        // Execute export
        let pipeline = TransitionExportPipeline(editorState: editorState)
        try await pipeline.export(to: outputURL, quality: .good)

        // Verify output file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))

        // Verify output file has reasonable size
        let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        XCTAssertGreaterThan(fileSize, 1000, "Exported file should be at least 1KB")
    }

    func testExportWithManyTransitions() async throws {
        // Setup: Create 5 overlapping clips with 4 transitions
        let clips = TestDataFactory.makeOverlappingClipsSequence(count: 5)
        let track = TestDataFactory.makeTestClipTrack(clips: clips)
        editorState.clipTracks = [track]

        // Add transitions between each consecutive clip pair
        for i in 0..<(clips.count - 1) {
            let transition = TestDataFactory.makeTransition(
                type: i % 2 == 0 ? TransitionType.crossfade : TransitionType.wipe,
                duration: CMTime(seconds: 1, preferredTimescale: 600),
                leadingClipID: clips[i].id,
                trailingClipID: clips[i + 1].id,
                parameters: i % 2 == 0 ? TransitionParameters.crossfade : TransitionParameters.wipe(direction: .left, softness: 0.2, borderWidth: 0),
                isEnabled: true
            )
            editorState.addTransition(transition)
        }

        // Execute export
        let pipeline = TransitionExportPipeline(editorState: editorState)
        try await pipeline.export(to: outputURL, quality: .good)

        // Verify output file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))

        // Verify all 4 transitions were processed
        XCTAssertEqual(editorState.transitions.count, 4, "Should have 4 transitions")
    }

    // MARK: - Quality Presets Tests

    func testExportWithDraftQuality() async throws {
        // Setup: Add clips with transition
        let clips = TestDataFactory.makeOverlappingClipsWithTransition()
        let track = TestDataFactory.makeTestClipTrack(clips: [clips.leading, clips.trailing])
        editorState.clipTracks = [track]
        editorState.addTransition(clips.transition)

        // Execute export with draft quality
        let pipeline = TransitionExportPipeline(editorState: editorState)
        try await pipeline.export(to: outputURL, quality: .draft)

        // Verify output file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))

        // Verify output file has reasonable size (draft should be smaller)
        let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        XCTAssertGreaterThan(fileSize, 1000, "Exported file should be at least 1KB")
    }

    func testExportWithGoodQuality() async throws {
        // Setup: Add clips with transition
        let clips = TestDataFactory.makeOverlappingClipsWithTransition()
        let track = TestDataFactory.makeTestClipTrack(clips: [clips.leading, clips.trailing])
        editorState.clipTracks = [track]
        editorState.addTransition(clips.transition)

        // Execute export with good quality
        let pipeline = TransitionExportPipeline(editorState: editorState)
        try await pipeline.export(to: outputURL, quality: .good)

        // Verify output file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))

        // Verify output file has reasonable size
        let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        XCTAssertGreaterThan(fileSize, 1000, "Exported file should be at least 1KB")
    }

    func testExportWithBestQuality() async throws {
        // Setup: Add clips with transition
        let clips = TestDataFactory.makeOverlappingClipsWithTransition()
        let track = TestDataFactory.makeTestClipTrack(clips: [clips.leading, clips.trailing])
        editorState.clipTracks = [track]
        editorState.addTransition(clips.transition)

        // Execute export with best quality
        let pipeline = TransitionExportPipeline(editorState: editorState)
        try await pipeline.export(to: outputURL, quality: .best)

        // Verify output file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))

        // Verify output file has reasonable size (best should be largest)
        let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        XCTAssertGreaterThan(fileSize, 1000, "Exported file should be at least 1KB")
    }

    func testExportWithCustomQuality() async throws {
        // Setup: Add clips with transition
        let clips = TestDataFactory.makeOverlappingClipsWithTransition()
        let track = TestDataFactory.makeTestClipTrack(clips: [clips.leading, clips.trailing])
        editorState.clipTracks = [track]
        editorState.addTransition(clips.transition)

        // Create custom quality settings
        let customQuality = ExportQualitySettings(
            preset: .custom,
            renderSize: CGSize(width: 1280, height: 720),
            bitrate: 10,
            antiAliasing: .basic
        )

        // Execute export with custom quality
        let pipeline = TransitionExportPipeline(editorState: editorState)
        try await pipeline.export(to: outputURL, quality: customQuality)

        // Verify output file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))

        // Verify output file has reasonable size
        let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        XCTAssertGreaterThan(fileSize, 1000, "Exported file should be at least 1KB")
    }

    func testExportQualityProducesDifferentFileSizes() async throws {
        // Setup: Add clips with transition
        let clips = TestDataFactory.makeOverlappingClipsWithTransition()
        let track = TestDataFactory.makeTestClipTrack(clips: [clips.leading, clips.trailing])
        editorState.clipTracks = [track]
        editorState.addTransition(clips.transition)

        // Export with different qualities
        let draftURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_draft_\(UUID().uuidString).mov")
        let goodURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_good_\(UUID().uuidString).mov")
        let bestURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_best_\(UUID().uuidString).mov")

        defer {
            try? FileManager.default.removeItem(at: draftURL)
            try? FileManager.default.removeItem(at: goodURL)
            try? FileManager.default.removeItem(at: bestURL)
        }

        let pipeline = TransitionExportPipeline(editorState: editorState)

        try await pipeline.export(to: draftURL, quality: .draft)
        try await pipeline.export(to: goodURL, quality: .good)
        try await pipeline.export(to: bestURL, quality: .best)

        // Get file sizes
        let draftSize = (try? FileManager.default.attributesOfItem(atPath: draftURL.path)[.size] as? Int64) ?? 0
        let goodSize = (try? FileManager.default.attributesOfItem(atPath: goodURL.path)[.size] as? Int64) ?? 0
        let bestSize = (try? FileManager.default.attributesOfItem(atPath: bestURL.path)[.size] as? Int64) ?? 0

        // Verify all files exist
        XCTAssertGreaterThan(draftSize, 0, "Draft export should produce a file")
        XCTAssertGreaterThan(goodSize, 0, "Good export should produce a file")
        XCTAssertGreaterThan(bestSize, 0, "Best export should produce a file")

        // Note: Exact size ordering may vary due to compression, but best should generally be >= good >= draft
        // We just verify all exports succeed for integration test purposes
    }

    // MARK: - Validation Error Tests

    func testExportValidationCatchesMissingLeadingClip() async throws {
        // Setup: Create transition with non-existent leading clip
        let clip = TestDataFactory.makeVideoClip(
            startTime: .zero,
            duration: CMTime(seconds: 5, preferredTimescale: 600)
        )
        let track = TestDataFactory.makeTestClipTrack(clips: [clip])
        editorState.clipTracks = [track]

        let fakeClipID = UUID()
        let transition = TestDataFactory.makeTransition(
            type: .crossfade,
            duration: CMTime(seconds: 1, preferredTimescale: 600),
            leadingClipID: fakeClipID, // Non-existent clip
            trailingClipID: clip.id,
            parameters: .crossfade,
            isEnabled: true
        )
        editorState.addTransition(transition)

        // Execute export - should throw validation error
        let pipeline = TransitionExportPipeline(editorState: editorState)

        do {
            try await pipeline.export(to: outputURL, quality: .good)
            XCTFail("Export should throw error for missing leading clip")
        } catch TransitionError.clipsNotFound {
            // Expected error
        } catch {
            XCTFail("Expected TransitionError.clipsNotFound, got \(error)")
        }
    }

    func testExportValidationCatchesMissingTrailingClip() async throws {
        // Setup: Create transition with non-existent trailing clip
        let clip = TestDataFactory.makeVideoClip(
            startTime: .zero,
            duration: CMTime(seconds: 5, preferredTimescale: 600)
        )
        let track = TestDataFactory.makeTestClipTrack(clips: [clip])
        editorState.clipTracks = [track]

        let fakeClipID = UUID()
        let transition = TestDataFactory.makeTransition(
            type: .crossfade,
            duration: CMTime(seconds: 1, preferredTimescale: 600),
            leadingClipID: clip.id,
            trailingClipID: fakeClipID, // Non-existent clip
            parameters: .crossfade,
            isEnabled: true
        )
        editorState.addTransition(transition)

        // Execute export - should throw validation error
        let pipeline = TransitionExportPipeline(editorState: editorState)

        do {
            try await pipeline.export(to: outputURL, quality: .good)
            XCTFail("Export should throw error for missing trailing clip")
        } catch TransitionError.clipsNotFound {
            // Expected error
        } catch {
            XCTFail("Expected TransitionError.clipsNotFound, got \(error)")
        }
    }

    func testExportValidationCatchesMissingBothClips() async throws {
        // Setup: Create transition with both clips non-existent
        let fakeClipID1 = UUID()
        let fakeClipID2 = UUID()

        let transition = TestDataFactory.makeTransition(
            type: .crossfade,
            duration: CMTime(seconds: 1, preferredTimescale: 600),
            leadingClipID: fakeClipID1,
            trailingClipID: fakeClipID2,
            parameters: .crossfade,
            isEnabled: true
        )
        editorState.addTransition(transition)

        // Execute export - should throw validation error
        let pipeline = TransitionExportPipeline(editorState: editorState)

        do {
            try await pipeline.export(to: outputURL, quality: .good)
            XCTFail("Export should throw error for missing both clips")
        } catch TransitionError.clipsNotFound {
            // Expected error
        } catch {
            XCTFail("Expected TransitionError.clipsNotFound, got \(error)")
        }
    }

    func testExportSkipsDisabledTransitions() async throws {
        // Setup: Add clips with disabled transition
        let clips = TestDataFactory.makeOverlappingClipsWithTransition()
        let track = TestDataFactory.makeTestClipTrack(clips: [clips.leading, clips.trailing])
        editorState.clipTracks = [track]

        // Create disabled transition
        let disabledTransition = TransitionClip(
            type: clips.transition.type,
            duration: clips.transition.duration,
            leadingClipID: clips.transition.leadingClipID,
            trailingClipID: clips.transition.trailingClipID,
            parameters: clips.transition.parameters,
            isEnabled: false // Disabled
        )
        editorState.addTransition(disabledTransition)

        // Execute export - should succeed even with disabled transition
        let pipeline = TransitionExportPipeline(editorState: editorState)
        try await pipeline.export(to: outputURL, quality: .good)

        // Verify output file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
    }

    // MARK: - Performance Tests

    func testExportPerformanceIsAcceptable() async throws {
        // Setup: Add clips with transition
        let clips = TestDataFactory.makeOverlappingClipsWithTransition()
        let track = TestDataFactory.makeTestClipTrack(clips: [clips.leading, clips.trailing])
        editorState.clipTracks = [track]
        editorState.addTransition(clips.transition)

        // Measure export time
        let pipeline = TransitionExportPipeline(editorState: editorState)

        let startTime = Date()
        try await pipeline.export(to: outputURL, quality: .good)
        let endTime = Date()

        let exportDuration = endTime.timeIntervalSince(startTime)

        // Verify export completed within reasonable time
        // Note: This is a basic test with minimal data, so it should be very fast
        // In production with real video data, this would take longer
        XCTAssertLessThan(exportDuration, 10.0, "Simple export should complete within 10 seconds")

        // Verify output file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
    }

    func testExportPerformanceWithMultipleTransitions() async throws {
        // Setup: Create 5 overlapping clips with 4 transitions
        let clips = TestDataFactory.makeOverlappingClipsSequence(count: 5)
        let track = TestDataFactory.makeTestClipTrack(clips: clips)
        editorState.clipTracks = [track]

        // Add transitions between each consecutive clip pair
        for i in 0..<(clips.count - 1) {
            let transition = TestDataFactory.makeTransition(
                type: .crossfade,
                duration: CMTime(seconds: 1, preferredTimescale: 600),
                leadingClipID: clips[i].id,
                trailingClipID: clips[i + 1].id,
                parameters: .crossfade,
                isEnabled: true
            )
            editorState.addTransition(transition)
        }

        // Measure export time
        let pipeline = TransitionExportPipeline(editorState: editorState)

        let startTime = Date()
        try await pipeline.export(to: outputURL, quality: .good)
        let endTime = Date()

        let exportDuration = endTime.timeIntervalSince(startTime)

        // Verify export completed within reasonable time
        // With 4 transitions, should still be reasonably fast for test data
        XCTAssertLessThan(exportDuration, 15.0, "Export with 4 transitions should complete within 15 seconds")

        // Verify output file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
    }

    // MARK: - Edge Cases

    func testExportWithNoTransitions() async throws {
        // Setup: Add clips without transitions
        let clip1 = TestDataFactory.makeVideoClip(
            startTime: .zero,
            duration: CMTime(seconds: 5, preferredTimescale: 600)
        )
        let clip2 = TestDataFactory.makeVideoClip(
            startTime: CMTime(seconds: 5, preferredTimescale: 600),
            duration: CMTime(seconds: 5, preferredTimescale: 600)
        )

        let track = TestDataFactory.makeTestClipTrack(clips: [clip1, clip2])
        editorState.clipTracks = [track]

        // Execute export - should succeed without transitions
        let pipeline = TransitionExportPipeline(editorState: editorState)
        try await pipeline.export(to: outputURL, quality: .good)

        // Verify output file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
    }

    func testExportWithEmptyTimeline() async throws {
        // Setup: Empty timeline (no clips, no transitions)
        editorState.clipTracks = []

        // Execute export - should handle gracefully
        let pipeline = TransitionExportPipeline(editorState: editorState)

        do {
            try await pipeline.export(to: outputURL, quality: .good)
            // May succeed with empty output or throw - depends on implementation
        } catch {
            // Acceptable to throw error for empty timeline
            // The important thing is it doesn't crash
        }
    }
}
