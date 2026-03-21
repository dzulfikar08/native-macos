import Foundation

/// Configuration for window recording
struct WindowRecordingSettings: Sendable {
    var selectedWindows: [WindowDevice] = []
    var qualityPreset: QualityPreset = .high
    var compositingMode: PipMode = .single
    var codec: VideoCodec = .h264
    var audioSettings: AudioSettings = AudioSettings()

    /// Validates settings before recording
    var isValid: Bool {
        // Must have at least one window
        guard !selectedWindows.isEmpty else {
            return false
        }

        // Maximum 4 windows
        guard selectedWindows.count <= 4 else {
            return false
        }

        // Compositing mode must match window count
        guard compositingMode.matchesWindowCount(selectedWindows.count) else {
            return false
        }

        return true
    }
}

// MARK: - PipMode Extension

extension PipMode {
    /// Checks if this mode matches the given window count
    /// Note: Validates the MODE TYPE matches the expected count (single/dual/triple/quad),
    /// not that the associated index values are in range. The indices are validated elsewhere.
    func matchesWindowCount(_ count: Int) -> Bool {
        switch self {
        case .single:
            return count == 1
        case .dual:
            return count == 2
        case .triple:
            return count == 3
        case .quad:
            return count == 4
        }
    }
}
