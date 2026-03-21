import XCTest
import AVFoundation
@testable import OpenScreen

final class AudioMixerTests: XCTestCase {
    func testAudioMixerCreatesBuffer() {
        let mixer = AudioMixer()
        let settings = AudioSettings()
        mixer.updateSettings(settings)

        // Verify mixer can process audio
        let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        buffer.frameLength = 1024

        // Should not throw
        mixer.processMicrophoneAudio(buffer)
    }

    func testVolumeControl() {
        let mixer = AudioMixer()
        var settings = AudioSettings()
        settings.systemVolume = 0.5
        settings.microphoneVolume = 0.75
        mixer.updateSettings(settings)

        // Verify volumes are applied
        // (actual verification happens in integration tests with real audio)
    }

    func testMute() {
        let mixer = AudioMixer()
        var settings = AudioSettings()
        settings.systemAudioEnabled = false
        settings.microphoneEnabled = true
        mixer.updateSettings(settings)

        // System audio should be muted
        // (actual verification in integration tests)
    }
}
