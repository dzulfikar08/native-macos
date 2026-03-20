import AVFoundation
import Foundation

/// Settings for webcam recording
struct WebcamRecordingSettings: Sendable {
    var selectedCameras: [CameraDevice]
    var compositingMode: PipMode
    var qualityPreset: QualityPreset
    var audioSettings: AudioSettings
    var codec: VideoCodec

    /// Default settings with enumerated cameras
    init() {
        self.selectedCameras = CameraDevice.enumerateCameras()
        self.compositingMode = .single
        self.qualityPreset = .high
        self.audioSettings = AudioSettings()
        self.codec = .h264
    }
}

/// Picture-in-picture compositing mode
enum PipMode: Equatable, Sendable {
    case single                        // Full screen
    case dual(main: Int, overlay: Int)  // Main full, overlay corner
    case triple(main: Int, p2: Int, p3: Int)  // 1 large, 2 small
    case quad                           // 2x2 grid
}

/// Quality preset for recording
enum QualityPreset: String, CaseIterable, Sendable {
    case low      // 480p, 24fps, 2 Mbps
    case medium   // 720p, 30fps, 5 Mbps
    case high     // 1080p, 30fps, 10 Mbps
    case ultra    // 4K, 60fps, 50 Mbps (if camera supports)
    case custom   // Manual controls

    var resolution: CGSize? {
        switch self {
        case .low: return CGSize(width: 640, height: 480)
        case .medium: return CGSize(width: 1280, height: 720)
        case .high: return CGSize(width: 1920, height: 1080)
        case .ultra: return CGSize(width: 3840, height: 2160)
        case .custom: return nil
        }
    }

    var framerate: Float {
        switch self {
        case .low: return 24.0
        case .medium, .high: return 30.0
        case .ultra: return 60.0
        case .custom: return 30.0
        }
    }

    var bitrate: Int? {
        switch self {
        case .low: return 2_000_000
        case .medium: return 5_000_000
        case .high: return 10_000_000
        case .ultra: return 50_000_000
        case .custom: return nil
        }
    }
}

/// Audio mixing settings
struct AudioSettings: Sendable {
    var systemAudioEnabled: Bool = true
    var microphoneEnabled: Bool = true
    var systemVolume: Float = 1.0      // 0.0 - 1.0
    var microphoneVolume: Float = 1.0  // 0.0 - 1.0
}

/// Video codec selection
enum VideoCodec: String, CaseIterable, Sendable {
    case h264 = "H.264"
    case hevc = "HEVC"
    case prores422 = "ProRes 422"
    case prores4444 = "ProRes 4444"

    var avCodecKey: AVVideoCodecType {
        switch self {
        case .h264: return .h264
        case .hevc: return .hevc
        case .prores422: return .proRes422
        case .prores4444: return .proRes4444
        }
    }

    var profileLevel: String? {
        switch self {
        case .h264: return AVVideoProfileLevelH264HighAutoLevel
        case .hevc:
            // HEVC uses different profile level constants
            if #available(macOS 10.13, *) {
                return nil // HEVC profile levels handled differently
            }
            return nil
        default: return nil
        }
    }

    static func availableCodecs() -> [VideoCodec] {
        var codecs: [VideoCodec] = [.h264]

        if #available(macOS 10.13, *) {
            codecs.append(.hevc)
        }

        // ProRes codecs available on macOS 10.7+
        codecs.append(.prores422)
        codecs.append(.prores4444)

        return codecs
    }

    func isAvailable() -> Bool {
        switch self {
        case .h264:
            return true
        case .hevc:
            if #available(macOS 10.13, *) {
                return true
            }
            return false
        case .prores422, .prores4444:
            if #available(macOS 10.7, *) {
                return true
            }
            return false
        }
    }
}

enum VideoError: LocalizedError {
    case codecNotSupported(VideoCodec)

    var errorDescription: String? {
        switch self {
        case .codecNotSupported(let codec):
            return "Codec '\(codec.rawValue)' is not available on this system"
        }
    }
}
