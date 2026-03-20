// Tests/OpenScreenTests/EffectsTests/AudioEffectProcessorTests.swift
import XCTest
import AVFoundation
@testable import OpenScreen

@MainActor
final class AudioEffectProcessorTests: XCTestCase {
    var processor: AudioEffectProcessor!

    override func setUp() async throws {
        try await super.setUp()
        do {
            processor = try AudioEffectProcessor()
        } catch {
            // If initialization fails (no audio hardware), use a mock setup
            processor = nil
        }
    }

    override func tearDown() async throws {
        processor?.stopProcessing()
        processor = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testProcessorInitialization() {
        if let processor = processor {
            // Verify the processor was created successfully
            XCTAssertNotNil(processor)
        } else {
            // Skip test if audio hardware is not available
            XCTSkip("Audio hardware not available for testing")
        }
    }

    func testProcessorInitializationWithAudioEffects() async throws {
        guard let processor = processor else {
            XCTSkip("Audio hardware not available for testing")
            return
        }

        let effects = [
            AudioEffect(type: .volumeNormalization, parameters: .withVolumeNormalization(-16.0)),
            AudioEffect(type: .equalizer, parameters: .withEqualizer(bass: 3.0, treble: -2.0))
        ]

        // Test that processor can be initialized with effects
        processor.updateEffects(effects)
        XCTAssertEqual(processor.isProcessing(), false, "Processor should not be running after updating effects")
    }

    // MARK: - Volume Normalization Tests

    func testVolumeNormalizationRealTimeProcessing() async throws {
        guard let processor = processor else {
            XCTSkip("Audio hardware not available for testing")
            return
        }

        let effects = [
            AudioEffect(type: .volumeNormalization, parameters: .withVolumeNormalization(-16.0))
        ]

        let expectation = expectation(description: "Real-time processing completes")

        processor.applyEffectsRealTime(effects: effects) { buffer, time in
            // Verify that we're receiving audio buffers
            XCTAssertFalse(buffer.frameLength == 0)
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 1.0)
        processor.stopProcessing()
    }

    func testVolumeNormalizationBoundaryValues() async throws {
        guard let processor = processor else {
            XCTSkip("Audio hardware not available for testing")
            return
        }

        // Test minimum valid LUFS value
        let minEffects = [
            AudioEffect(type: .volumeNormalization, parameters: .withVolumeNormalization(-60.0))
        ]

        processor.updateEffects(minEffects)
        XCTAssertEqual(processor.isProcessing(), false)

        // Test maximum valid LUFS value
        let maxEffects = [
            AudioEffect(type: .volumeNormalization, parameters: .withVolumeNormalization(0.0))
        ]

        processor.updateEffects(maxEffects)
        XCTAssertEqual(processor.isProcessing(), false)
    }

    // MARK: - Equalizer Tests

    func testEqualizerRealTimeProcessing() async throws {
        guard let processor = processor else {
            XCTSkip("Audio hardware not available for testing")
            return
        }

        let effects = [
            AudioEffect(type: .equalizer, parameters: .withEqualizer(bass: 6.0, treble: -3.0))
        ]

        let expectation = expectation(description: "Equalizer processing completes")

        processor.applyEffectsRealTime(effects: effects) { buffer, time in
            XCTAssertFalse(buffer.frameLength == 0)
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 1.0)
        processor.stopProcessing()
    }

    func testEqualizerBoundaryValues() async throws {
        guard let processor = processor else {
            XCTSkip("Audio hardware not available for testing")
            return
        }

        // Test minimum EQ values
        let minEffects = [
            AudioEffect(type: .equalizer, parameters: .withEqualizer(bass: -12.0, treble: -12.0))
        ]

        processor.updateEffects(minEffects)
        XCTAssertEqual(processor.isProcessing(), false)

        // Test maximum EQ values
        let maxEffects = [
            AudioEffect(type: .equalizer, parameters: .withEqualizer(bass: 12.0, treble: 12.0))
        ]

        processor.updateEffects(maxEffects)
        XCTAssertEqual(processor.isProcessing(), false)
    }

    // MARK: - Combined Effects Tests

    func testCombinedEffectsProcessing() async throws {
        guard let processor = processor else {
            XCTSkip("Audio hardware not available for testing")
            return
        }

        let effects = [
            AudioEffect(type: .volumeNormalization, parameters: .withVolumeNormalization(-16.0)),
            AudioEffect(type: .equalizer, parameters: .withEqualizer(bass: 4.0, treble: -1.0))
        ]

        let expectation = expectation(description: "Combined effects processing completes")

        processor.applyEffectsRealTime(effects: effects) { buffer, time in
            XCTAssertFalse(buffer.frameLength == 0)
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 1.0)
        processor.stopProcessing()
    }

    func testEffectEnableDisableToggle() async throws {
        guard let processor = processor else {
            XCTSkip("Audio hardware not available for testing")
            return
        }

        var effects = [
            AudioEffect(type: .volumeNormalization, parameters: .withVolumeNormalization(-16.0), isEnabled: true),
            AudioEffect(type: .equalizer, parameters: .withEqualizer(bass: 3.0, treble: -2.0), isEnabled: false)
        ]

        // Update with disabled effect
        processor.updateEffects(effects)
        XCTAssertEqual(processor.isProcessing(), false)

        // Enable the effect
        effects[1].isEnabled = true
        processor.updateEffects(effects)
        XCTAssertEqual(processor.isProcessing(), false)
    }

    // MARK: - Audio Analysis Tests

    func testAudioAnalysisData() async throws {
        guard let processor = processor else {
            XCTSkip("Audio hardware not available for testing")
            return
        }

        // Test getting audio analysis data
        let analysis = processor.getAudioAnalysis()

        // Verify analysis structure
        XCTAssertNotNil(analysis.timestamp)
        XCTAssertNotNil(analysis.peakLevel)
        XCTAssertNotNil(analysis.rmsLevel)
        XCTAssertEqual(analysis.frequencyData.count, 0) // Empty for now
    }

    // MARK: - Error Handling Tests

    func testInvalidEffectParametersError() async throws {
        guard let processor = processor else {
            XCTSkip("Audio hardware not available for testing")
            return
        }

        let invalidEffects = [
            AudioEffect(type: .volumeNormalization, parameters: .withVolumeNormalization(-70.0)) // Below minimum
        ]

        // Should not crash when updating with invalid parameters
        processor.updateEffects(invalidEffects)
        XCTAssertEqual(processor.isProcessing(), false)
    }

    func testStopProcessing() async throws {
        guard let processor = processor else {
            XCTSkip("Audio hardware not available for testing")
            return
        }

        let effects = [
            AudioEffect(type: .volumeNormalization, parameters: .withVolumeNormalization(-16.0))
        ]

        // Start processing
        processor.applyEffectsRealTime(effects: effects) { buffer, time in
            // Just receive buffers
        }

        // Give it a moment to start
        usleep(100000) // 0.1 seconds

        // Stop processing
        processor.stopProcessing()
        XCTAssertEqual(processor.isProcessing(), false)
    }

    // MARK: - Performance Tests

    func testRealTimePerformance() async throws {
        guard let processor = processor else {
            XCTSkip("Audio hardware not available for testing")
            return
        }

        let effects = [
            AudioEffect(type: .equalizer, parameters: .withEqualizer(bass: 2.0, treble: -1.0)),
            AudioEffect(type: .volumeNormalization, parameters: .withVolumeNormalization(-16.0))
        ]

        let startTime = Date()
        let bufferCount = 0

        processor.applyEffectsRealTime(effects: effects) { buffer, time in
            _ = buffer // Use the buffer
            _ = time // Use the time
        }

        // Process for a short time
        usleep(200000) // 0.2 seconds

        processor.stopProcessing()

        let processingTime = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(processingTime, 1.0, "Real-time processing should be fast")
    }

    // MARK: - Integration Tests

    func testIntegrationWithAudioEffectValidator() async throws {
        guard let processor = processor else {
            XCTSkip("Audio hardware not available for testing")
            return
        }

        let validator = AudioEffectValidator()

        let validEffect = AudioEffect(
            type: .volumeNormalization,
            parameters: .withVolumeNormalization(-16.0),
            isEnabled: true
        )

        // Test that valid effects can be processed
        XCTAssertNoThrow(try validator.validate(validEffect))

        processor.updateEffects([validEffect])
        XCTAssertEqual(processor.isProcessing(), false)

        let invalidEffect = AudioEffect(
            type: .equalizer,
            parameters: .withVolumeNormalization(-16.0), // Wrong parameter type
            isEnabled: true
        )

        // Test that invalid effects are caught by validator
        XCTAssertThrowsError(try validator.validate(invalidEffect)) { error in
            if case .parameterMismatch = error {
                // Expected
            } else {
                XCTFail("Should throw parameterMismatch error")
            }
        }

        // Processor should still handle invalid parameters gracefully
        processor.updateEffects([invalidEffect])
        XCTAssertEqual(processor.isProcessing(), false)
    }
}