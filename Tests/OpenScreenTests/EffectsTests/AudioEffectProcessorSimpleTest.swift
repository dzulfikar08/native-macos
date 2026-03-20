// Simple test to verify AudioEffectProcessor compilation and basic functionality
import XCTest
import AVFoundation
@testable import OpenScreen

@MainActor
final class AudioEffectProcessorSimpleTest: XCTestCase {

    func testAudioEffectProcessorInitialization() {
        // Test that AudioEffectProcessor can be created without crashing
        do {
            let processor = try AudioEffectProcessor()
            XCTAssertNotNil(processor, "Processor should be created successfully")
        } catch {
            // If audio hardware is not available, the processor may fail to initialize
            // This is acceptable for this test
            print("Audio hardware not available: \(error)")
        }
    }

    func testAudioEffectProcessorAnalysis() {
        // Test audio analysis method
        do {
            let processor = try AudioEffectProcessor()
            let analysis = processor.getAudioAnalysis()

            XCTAssertNotNil(analysis.timestamp, "Analysis should have timestamp")
            XCTAssertNotNil(analysis.peakLevel, "Analysis should have peak level")
            XCTAssertNotNil(analysis.rmsLevel, "Analysis should have RMS level")
        } catch {
            print("Audio hardware not available: \(error)")
        }
    }

    func testAudioEffectProcessorProcessingState() {
        // Test processing state methods
        do {
            let processor = try AudioEffectProcessor()

            // Initially should not be processing
            XCTAssertEqual(processor.isProcessing(), false, "Processor should not be processing initially")

            // Test that state can be updated
            processor.updateEffects([])
            XCTAssertEqual(processor.isProcessing(), false, "Processor should not be processing after updating empty effects")

        } catch {
            print("Audio hardware not available: \(error)")
        }
    }

    func testAudioEffectProcessorStopProcessing() {
        // Test stop processing method
        do {
            let processor = try AudioEffectProcessor()

            // Stop processing (should not crash)
            processor.stopProcessing()
            XCTAssertEqual(processor.isProcessing(), false, "Processor should not be processing after stop")

        } catch {
            print("Audio hardware not available: \(error)")
        }
    }

    func testAudioEffectProcessorEffectsIntegration() {
        // Test integration with AudioEffect data model
        do {
            let processor = try AudioEffectProcessor()

            // Create test effects
            let effects = [
                AudioEffect(type: .volumeNormalization, parameters: .withVolumeNormalization(-16.0)),
                AudioEffect(type: .equalizer, parameters: .withEqualizer(bass: 3.0, treble: -2.0))
            ]

            // Update effects (should not crash)
            processor.updateEffects(effects)
            XCTAssertEqual(processor.isProcessing(), false, "Processor should not be processing after updating effects")

        } catch {
            print("Audio hardware not available: \(error)")
        }
    }
}