import Foundation

enum ExportQualityPreset: String, Codable, Sendable {
    case draft      // 720p, fast
    case good       // 1080p, balanced
    case best       // Source resolution, high quality
    case custom     // User-specified settings
}

struct ExportQualitySettings: Codable, Sendable {
    let preset: ExportQualityPreset
    let renderSize: CGSize?           // nil = source resolution
    let bitrate: Int?                 // Mbps, nil = preset default
    let antiAliasing: AntiAliasingMode? // nil = preset default

    enum AntiAliasingMode: String, Codable {
        case none
        case basic
        case multiSample
    }

    static var draft: ExportQualitySettings {
        ExportQualitySettings(
            preset: .draft,
            renderSize: CGSize(width: 1280, height: 720),
            bitrate: 5,
            antiAliasing: .none
        )
    }

    static var good: ExportQualitySettings {
        ExportQualitySettings(
            preset: .good,
            renderSize: CGSize(width: 1920, height: 1080),
            bitrate: 15,
            antiAliasing: .basic
        )
    }

    static var best: ExportQualitySettings {
        ExportQualitySettings(
            preset: .best,
            renderSize: nil, // Source resolution
            bitrate: 30,
            antiAliasing: .multiSample
        )
    }
}