import AVFoundation

/// Generates audio waveform data for visualization in timeline
final class AudioWaveformGenerator: @unchecked Sendable {

    /// Generate waveform data from audio buffer
    /// - Parameters:
    ///   - buffer: Audio buffer containing PCM data
    ///   - resolution: Number of data points to generate
    /// - Returns: Array of RMS amplitude values (0.0 to 1.0)
    func generate(from buffer: AVAudioPCMBuffer, resolution: Int) async throws -> [Double] {
        guard resolution > 0 else {
            throw TimelineError.waveformGenerationFailed
        }

        guard buffer.frameLength > 0 else {
            return Array(repeating: 0.0, count: resolution)
        }

        let channelData = buffer.floatChannelData
        let frameCount = Int(buffer.frameLength)
        let samplesPerPoint = max(1, frameCount / resolution)

        var waveform: [Double] = []
        waveform.reserveCapacity(resolution)

        for i in 0..<resolution {
            let startSample = i * samplesPerPoint
            let endSample = min(startSample + samplesPerPoint, frameCount)

            var sumSquares: Double = 0.0
            var sampleCount = 0

            for j in startSample..<endSample {
                // Handle multi-channel audio by averaging channels
                var sampleSum: Float = 0.0
                for channel in 0..<Int(buffer.format.channelCount) {
                    sampleSum += abs(channelData![channel][j])
                }
                let sample = sampleSum / Float(buffer.format.channelCount)
                sumSquares += Double(sample * sample)
                sampleCount += 1
            }

            let rms = sampleCount > 0 ? sqrt(sumSquares / Double(sampleCount)) : 0.0
            waveform.append(rms)
        }

        return waveform
    }
}
