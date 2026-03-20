import AVFoundation
import Foundation

/// Mixes system audio and microphone audio with per-source controls
@MainActor
final class AudioMixer: Sendable {
    private var settings: AudioSettings
    private let outputFormat: AVAudioFormat

    // Buffer management
    private var systemBuffer: AVAudioPCMBuffer?
    private var micBuffer: AVAudioPCMBuffer?
    private let bufferSize: AVAudioFrameCount = 8192

    init() {
        // Standardize on 48kHz stereo for output
        self.outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48000,
            channels: 2,
            interleaved: true
        )!

        self.settings = AudioSettings()
    }

    /// Update audio mixing settings
    func updateSettings(_ settings: AudioSettings) {
        self.settings = settings
    }

    /// Process system audio buffer
    func processSystemAudio(_ buffer: AVAudioBuffer) {
        guard settings.systemAudioEnabled else { return }

        guard let pcmBuffer = buffer as? AVAudioPCMBuffer else { return }

        // Apply volume control
        if settings.systemVolume != 1.0 {
            applyVolume(to: pcmBuffer, volume: settings.systemVolume)
        }

        systemBuffer = pcmBuffer
    }

    /// Process microphone audio buffer
    func processMicrophoneAudio(_ buffer: AVAudioBuffer) {
        guard settings.microphoneEnabled else { return }

        guard let pcmBuffer = buffer as? AVAudioPCMBuffer else { return }

        // Apply volume control
        if settings.microphoneVolume != 1.0 {
            applyVolume(to: pcmBuffer, volume: settings.microphoneVolume)
        }

        micBuffer = pcmBuffer
    }

    /// Get mixed audio buffer
    /// - Returns: Mixed buffer or nil if no audio available
    func getMixedBuffer() -> AVAudioPCMBuffer? {
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: bufferSize
        ) else {
            return nil
        }

        outputBuffer.frameLength = bufferSize

        // Mix system and mic audio
        if let system = systemBuffer, let mic = micBuffer {
            mixBuffers(system, mic, into: outputBuffer)
        } else if let system = systemBuffer {
            copyBuffer(system, to: outputBuffer)
        } else if let mic = micBuffer {
            copyBuffer(mic, to: outputBuffer)
        } else {
            return nil
        }

        return outputBuffer
    }

    // MARK: - Private Helpers

    private func applyVolume(to buffer: AVAudioPCMBuffer, volume: Float) {
        guard let floatChannelData = buffer.floatChannelData else { return }

        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        for channel in 0..<channelCount {
            for frame in 0..<frameCount {
                floatChannelData[channel][frame] *= volume
            }
        }
    }

    private func mixBuffers(
        _ buffer1: AVAudioPCMBuffer,
        _ buffer2: AVAudioPCMBuffer,
        into output: AVAudioPCMBuffer
    ) {
        guard let data1 = buffer1.floatChannelData,
              let data2 = buffer2.floatChannelData,
              let outputData = output.floatChannelData else {
            return
        }

        let frameCount = Int(output.frameLength)
        let channelCount = Int(output.format.channelCount)

        for channel in 0..<channelCount {
            for frame in 0..<frameCount {
                // Mix with clipping protection
                let mixed = data1[channel][frame] + data2[channel][frame]
                outputData[channel][frame] = min(max(mixed, -1.0), 1.0)
            }
        }
    }

    private func copyBuffer(_ source: AVAudioPCMBuffer, to dest: AVAudioPCMBuffer) {
        guard let sourceData = source.floatChannelData,
              let destData = dest.floatChannelData else {
            return
        }

        let frameCount = min(Int(source.frameLength), Int(dest.frameLength))
        let channelCount = Int(source.format.channelCount)

        for channel in 0..<channelCount {
            for frame in 0..<frameCount {
                destData[channel][frame] = sourceData[channel][frame]
            }
        }
    }
}
