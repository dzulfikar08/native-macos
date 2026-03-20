import XCTest
import AVFoundation
@testable import OpenScreen

final class AudioWaveformGeneratorTests: XCTestCase {
    func testGenerateWaveformFromSilentAudio() async throws {
        // Create silent audio buffer
        let sampleRate: Double = 44100.0
        let duration: Double = 1.0
        let frameCount = AVAudioFrameCount(sampleRate * duration)

        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        )!

        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        // Fill with silence
        let channelData = buffer.floatChannelData![0]
        for i in 0..<Int(frameCount) {
            channelData[i] = 0.0
        }

        let generator = AudioWaveformGenerator()
        let waveform = try await generator.generate(from: buffer, resolution: 100)

        XCTAssertEqual(waveform.count, 100)
        XCTAssertTrue(waveform.allSatisfy { $0 == 0.0 }, "Silent audio should produce zero amplitude")
    }

    func testGenerateWaveformFromSineWave() async throws {
        // Create sine wave buffer
        let sampleRate: Double = 44100.0
        let duration: Double = 1.0
        let frequency: Double = 440.0 // A4 note
        let frameCount = AVAudioFrameCount(sampleRate * duration)

        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        )!

        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        // Fill with sine wave
        let channelData = buffer.floatChannelData![0]
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            channelData[i] = Float(sin(2.0 * .pi * frequency * t))
        }

        let generator = AudioWaveformGenerator()
        let waveform = try await generator.generate(from: buffer, resolution: 100)

        XCTAssertEqual(waveform.count, 100)
        // Sine wave should have consistent amplitude around 0.707 (RMS of sine)
        let avgAmplitude = waveform.reduce(0.0, +) / Double(waveform.count)
        XCTAssertTrue(avgAmplitude > 0.6 && avgAmplitude < 0.8, "Average amplitude should be around 0.707")
    }

    func testGenerateWaveformResolution() async throws {
        // Test that resolution parameter works correctly
        let sampleRate: Double = 44100.0
        let duration: Double = 1.0
        let frameCount = AVAudioFrameCount(sampleRate * duration)

        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        )!

        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        // Fill with noise
        let channelData = buffer.floatChannelData![0]
        for i in 0..<Int(frameCount) {
            channelData[i] = Float.random(in: -1.0...1.0)
        }

        let generator = AudioWaveformGenerator()

        // Test different resolutions
        let waveform50 = try await generator.generate(from: buffer, resolution: 50)
        let waveform100 = try await generator.generate(from: buffer, resolution: 100)
        let waveform200 = try await generator.generate(from: buffer, resolution: 200)

        XCTAssertEqual(waveform50.count, 50)
        XCTAssertEqual(waveform100.count, 100)
        XCTAssertEqual(waveform200.count, 200)
    }
}
