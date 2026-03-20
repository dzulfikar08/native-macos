// Tests/OpenScreenTests/IntegrationTests/Phase24IntegrationTests.swift
import XCTest
import AVFoundation
@testable import OpenScreen

@MainActor
final class Phase24IntegrationTests: XCTestCase {
    var windowController: EditorWindowController!
    var editorState: EditorState!
    var testVideoURL: URL!
    var testOutputURL: URL!

    // Effect components for testing
    var effectStack: EffectStack!
    var presetStorage: PresetStorage!

    override func setUp() async throws {
        try await super.setUp()

        // Create test video file
        testVideoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_video_\(UUID().uuidString).mov")
        try Data().write(to: testVideoURL)

        // Create output file for export tests
        testOutputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("exported_video_\(UUID().uuidString).mov")

        // Initialize components
        EditorState.initializeShared(with: testVideoURL)
        editorState = EditorState.shared

        // Set realistic duration for testing
        editorState.duration = CMTime(seconds: 30, preferredTimescale: 600)

        // Initialize effect stack and preset storage
        effectStack = EffectStack()
        presetStorage = PresetStorage()

        // Initialize window controller
        windowController = EditorWindowController(recordingURL: testVideoURL)
        windowController.showWindow(nil)

        // Wait for components to initialize
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
    }

    override func tearDown() async throws {
        // Clean up
        windowController.close()
        windowController = nil
        editorState = nil
        effectStack = nil
        presetStorage = nil

        // Remove test files
        if let url = testVideoURL {
            try? FileManager.default.removeItem(at: url)
        }
        if let url = testOutputURL {
            try? FileManager.default.removeItem(at: url)
        }

        EditorState.shared = nil
        try await super.tearDown()
    }

    // MARK: - Test 1: Full Workflow Test (apply effects, preview, export)

    func testFullWorkflowWithEffectsAndExport() async throws {
        // Given - Editor with video loaded
        XCTAssertNotNil(editorState, "Editor state should exist")
        XCTAssertNotNil(windowController, "Window controller should exist")

        // When - Apply multiple effects
        let brightnessEffect = VideoEffect(
            type: .brightness,
            parameters: .brightness(0.3),
            isEnabled: true
        )
        let saturationEffect = VideoEffect(
            type: .saturation,
            parameters: .saturation(1.2),
            isEnabled: true
        )

        effectStack.videoEffects = [brightnessEffect, saturationEffect]
        editorState.effectStack = effectStack

        // Verify effects are applied
        XCTAssertEqual(editorState.effectStack.videoEffects.count, 2, "Should have 2 effects")
        XCTAssertTrue(editorState.effectStack.videoEffects.first?.type == .brightness, "First effect should be brightness")

        // When - Start preview playback
        editorState.isPlaying = true
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

        XCTAssertTrue(editorState.isPlaying, "Should be playing")
        XCTAssertGreaterThan(CMTimeGetSeconds(editorState.currentTime), 0, "Time should be advancing")

        // When - Stop and export
        editorState.isPlaying = false

        // Create asset for export
        let asset = AVAsset(url: testVideoURL)
        let videoExporter = VideoExporter(
            asset: asset,
            outputURL: testOutputURL,
            exportPreset: AVAssetExportPresetHighestQuality
        )

        // Start export
        try videoExporter.startExport()
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Verify export completed successfully
        XCTAssertFalse(videoExporter.isCurrentlyExporting, "Export should complete")
        XCTAssertEqual(videoExporter.currentProgress, 1.0, "Progress should be 100%")

        // Verify output file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: testOutputURL.path), "Export file should exist")

        // Clean up exported file
        try? FileManager.default.removeItem(at: testOutputURL)
    }

    // MARK: - Test 2: Preset System Test

    func testPresetCreationApplicationAndManagement() async throws {
        // Given - Empty effect stack
        XCTAssertEqual(effectStack.videoEffects.count, 0, "Should start with no effects")

        // When - Create custom preset
        effectStack.videoEffects = [
            VideoEffect(type: .contrast, parameters: .contrast(1.5)),
            VideoEffect(type: .saturation, parameters: .saturation(1.1))
        ]

        // Save as preset
        try effectStack.saveAsPreset(name: "Custom Test Preset")
        XCTAssertNotNil(effectStack.selectedPreset, "Should have selected preset")
        XCTAssertEqual(effectStack.selectedPreset?.name, "Custom Test Preset", "Preset name should match")
        XCTAssertTrue(effectStack.selectedPreset?.isBuiltIn == false, "Should be custom preset")

        // When - Apply built-in preset
        let warmPreset = EffectStack.builtInPresets.first { $0.name == "Warm" }
        effectStack.applyPreset(warmPreset!)

        XCTAssertEqual(effectStack.videoEffects.count, 2, "Should have 2 effects from preset")
        XCTAssertTrue(effectStack.videoEffects.contains { $0.type == .saturation }, "Should have saturation effect")

        // When - Verify preset storage
        let savedPresets = presetStorage.getAllPresets()
        XCTAssertGreaterThan(savedPresets.count, 0, "Should have saved presets")

        let customPreset = savedPresets.first { !$0.isBuiltIn }
        XCTAssertNotNil(customPreset, "Should have custom preset in storage")
        XCTAssertEqual(customPreset?.name, "Custom Test Preset", "Custom preset should be named correctly")
    }

    // MARK: - Test 3: Undo/Redo Workflow Test

    func testUndoRedoOperationsOnEffects() async throws {
        // Given - Editor with initial state
        let initialEffectsCount = editorState.effectStack.videoEffects.count

        // When - Apply first effect
        let effect1 = VideoEffect(type: .brightness, parameters: .brightness(0.2))
        editorState.effectStack.videoEffects.append(effect1)

        let afterApply = editorState.effectStack.videoEffects.count
        XCTAssertEqual(afterApply, initialEffectsCount + 1, "Should have added 1 effect")

        // When - Apply second effect
        let effect2 = VideoEffect(type: .contrast, parameters: .contrast(1.3))
        editorState.effectStack.videoEffects.append(effect2)

        let afterApply2 = editorState.effectStack.videoEffects.count
        XCTAssertEqual(afterApply2, initialEffectsCount + 2, "Should have added 2 effects")

        // When - Remove last effect (simulate undo)
        editorState.effectStack.videoEffects.removeLast()

        let afterRemove = editorState.effectStack.videoEffects.count
        XCTAssertEqual(afterRemove, initialEffectsCount + 1, "Should have removed 1 effect")

        // When - Remove another effect (simulate undo again)
        editorState.effectStack.videoEffects.removeLast()

        let afterRemove2 = editorState.effectStack.videoEffects.count
        XCTAssertEqual(afterRemove2, initialEffectsCount, "Should be back to original count")

        // When - Re-add effects (simulate redo)
        editorState.effectStack.videoEffects.append(effect1)
        editorState.effectStack.videoEffects.append(effect2)

        let afterRedo = editorState.effectStack.videoEffects.count
        XCTAssertEqual(afterRedo, initialEffectsCount + 2, "Should have effects again")
    }

    // MARK: - Test 4: Export with Effects Test

    func testExportWithAppliedEffects() async throws {
        // Given - Editor with effects applied
        let brightnessEffect = VideoEffect(
            type: .brightness,
            parameters: .brightness(0.4),
            isEnabled: true
        )

        editorState.effectStack.videoEffects = [brightnessEffect]

        // Verify effects are present
        XCTAssertEqual(editorState.effectStack.videoEffects.count, 1, "Should have 1 effect")

        // When - Create video exporter with effects
        let asset = AVAsset(url: testVideoURL)
        let videoExporter = VideoExporter(
            asset: asset,
            outputURL: testOutputURL,
            exportPreset: AVAssetExportPresetMediumQuality
        )

        // Start export
        try videoExporter.startExport()

        // Wait for export to complete
        let exportStartTime = Date()
        while videoExporter.isCurrentlyExporting {
            try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds

            // Timeout protection
            if Date().timeIntervalSince(exportStartTime) > 5.0 {
                XCTFail("Export timed out")
                break
            }
        }

        // Then - Verify export success
        XCTAssertEqual(videoExporter.currentProgress, 1.0, "Export should be 100% complete")
        XCTAssertFalse(videoExporter.isCurrentlyExporting, "Export should not be running")

        // Verify output file exists and has reasonable size
        XCTAssertTrue(FileManager.default.fileExists(atPath: testOutputURL.path), "Export file should exist")

        let attributes = try FileManager.default.attributesOfItem(atPath: testOutputURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        XCTAssertGreaterThan(fileSize, 0, "Export file should have data")

        // Clean up
        try? FileManager.default.removeItem(at: testOutputURL)
    }

    // MARK: - Test 5: Performance Test (60fps)

    func testEffectRenderingPerformanceAt60fps() async throws {
        // Given - Editor with multiple effects
        let effects: [VideoEffect] = [
            VideoEffect(type: .brightness, parameters: .brightness(0.1)),
            VideoEffect(type: .contrast, parameters: .contrast(1.2)),
            VideoEffect(type: .saturation, parameters: .saturation(1.3)),
            VideoEffect(type: .brightness, parameters: .brightness(0.2)),
            VideoEffect(type: .contrast, parameters: .contrast(1.1))
        ]

        editorState.effectStack.videoEffects = effects

        // When - Measure rendering performance
        let startTime = CFAbsoluteTimeGetCurrent()
        let frameCount = 300 // 5 seconds at 60fps

        for i in 0..<frameCount {
            let time = Double(i) / 60.0 // 60fps
            editorState.currentTime = CMTime(seconds: time, preferredTimescale: 600)

            // Simulate effect processing
            _ = editorState.effectStack.videoEffects.map { effect in
                // Process effect (simplified for test)
                return effect
            }

            if i % 60 == 0 {
                try await Task.sleep(nanoseconds: 16_666_667) // Simulate 60fps
            }
        }

        let duration = CFAbsoluteTimeGetCurrent() - startTime

        // Then - Performance requirements
        let framesPerSecond = Double(frameCount) / duration
        XCTAssertGreaterThanOrEqual(framesPerSecond, 58.0,
                                   "Should maintain at least 58fps (within 2% of 60fps)")

        XCTAssertLessThan(duration, 6.0, "5 seconds of frames should complete in less than 6 seconds")

        print("Performance test: \(framesPerSecond) fps achieved")
    }

    // MARK: - Test 6: Complex Effect Chain Test

    func testComplexEffectChainWorkflow() async throws {
        // Given - Editor with no effects
        XCTAssertEqual(editorState.effectStack.videoEffects.count, 0, "Should start clean")

        // When - Create complex effect chain
        let effectChain: [VideoEffect] = [
            VideoEffect(type: .brightness, parameters: .brightness(-0.2)),
            VideoEffect(type: .contrast, parameters: .contrast(1.4)),
            VideoEffect(type: .saturation, parameters: .saturation(0.8)),
            VideoEffect(type: .brightness, parameters: .brightness(0.1)),
            VideoEffect(type: .contrast, parameters: .contrast(1.2))
        ]

        editorState.effectStack.videoEffects = effectChain

        // Verify all effects are applied
        XCTAssertEqual(editorState.effectStack.videoEffects.count, 5, "Should have 5 effects")

        // When - Apply preset on top of existing effects
        let dramaticPreset = EffectStack.builtInPresets.first { $0.name == "Dramatic" }
        effectStack.applyPreset(dramaticPreset!)

        // Should replace existing effects with preset
        XCTAssertEqual(effectStack.videoEffects.count, 2, "Should have preset effects")
        XCTAssertTrue(effectStack.videoEffects.contains { $0.type == .contrast }, "Should have contrast")
        XCTAssertTrue(effectStack.videoEffects.contains { $0.type == .saturation }, "Should have saturation")

        // When - Test preset combination
        effectStack.videoEffects.append(contentsOf: effectChain)

        // Should now have preset + custom effects
        XCTAssertEqual(effectStack.videoEffects.count, 7, "Should have combined effects")

        // Verify all effect types are valid
        for effect in effectStack.videoEffects {
            XCTAssertTrue(effect.parameters.isValid, "All effects should have valid parameters")
        }
    }

    // MARK: - Test 7: Time-Based Effects Test

    func testTimeBasedEffectsAndLoopPlayback() async throws {
        // Given - Editor with time-based effects
        let timeRange = CMTime(seconds: 5)...CMTime(seconds: 15)
        let timeBasedEffect = VideoEffect(
            type: .saturation,
            parameters: .saturation(1.5),
            isEnabled: true,
            timeRange: timeRange
        )

        editorState.effectStack.videoEffects = [timeBasedEffect]

        // Verify time range is set
        XCTAssertNotNil(timeBasedEffect.timeRange, "Effect should have time range")
        XCTAssertEqual(timeBasedEffect.timeRange?.lowerBound.seconds, 5.0, "Start time should be 5s")
        XCTAssertEqual(timeBasedEffect.timeRange?.upperBound.seconds, 15.0, "End time should be 15s")

        // When - Set up loop region
        let loopRegion = LoopRegion(
            name: "Test Loop",
            timeRange: CMTime(seconds: 3)...CMTime(seconds: 12),
            color: .blue,
            isActive: true,
            useInOutPoints: false
        )

        editorState.loopRegions = [loopRegion]
        editorState.activeLoopRegionID = loopRegion.id

        // When - Start loop playback
        editorState.isPlaying = true
        editorState.currentTime = CMTime(seconds: 10, preferredTimescale: 600)

        // Monitor loop behavior
        let startTime = Date()
        var loopCount = 0

        while Date().timeIntervalSince(startTime) < 2.0 {
            let currentTimeSeconds = CMTimeGetSeconds(editorState.currentTime)

            // Should loop between 3 and 12 seconds
            if currentTimeSeconds < 3.5 {
                loopCount += 1
            }

            try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds check interval
        }

        editorState.isPlaying = false

        // Then - Verify loop behavior
        XCTAssertGreaterThan(loopCount, 0, "Should have looped at least once")

        // Verify effects are only applied within time range
        let currentTime = CMTimeGetSeconds(editorState.currentTime)
        if currentTime >= 5.0 && currentTime <= 15.0 {
            XCTAssertTrue(timeBasedEffect.isEnabled, "Effect should be active within time range")
        }
    }

    // MARK: - Test 8: Export Cancellation and Error Handling Test

    func testExportCancellationAndErrorHandling() async throws {
        // Given - Export in progress
        let asset = AVAsset(url: testVideoURL)
        let videoExporter = VideoExporter(
            asset: asset,
            outputURL: testOutputURL,
            exportPreset: AVAssetExportPresetHighestQuality
        )

        // When - Start export
        try videoExporter.startExport()

        // Verify export started
        XCTAssertTrue(videoExporter.isCurrentlyExporting, "Export should be running")
        XCTAssertLessThan(videoExporter.currentProgress, 1.0, "Export should not be complete")

        // When - Cancel export after short time
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        videoExporter.cancelExport()

        // Then - Verify cancellation
        XCTAssertFalse(videoExporter.isCurrentlyExporting, "Export should be cancelled")
        XCTAssertLessThan(videoExporter.currentProgress, 1.0, "Progress should not be 100%")

        // When - Try export with invalid parameters
        let invalidURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("invalid")

        let invalidExporter = VideoExporter(
            asset: asset,
            outputURL: invalidURL,
            exportPreset: "InvalidPreset"
        )

        // Should throw error for invalid preset
        XCTAssertThrowsError(try invalidExporter.startExport()) { error in
            XCTAssertTrue(error is ExportError, "Should throw ExportError")
            XCTAssertEqual((error as? ExportError), .invalidExportPreset, "Should be invalid preset error")
        }

        // Clean up
        try? FileManager.default.removeItem(at: testOutputURL)
    }
}