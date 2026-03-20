import Foundation
import CoreMedia
import AppKit

/// Metadata extracted from a video file
struct VideoMetadata: Sendable {
    let duration: CMTime
    let durationString: String
    let resolution: CGSize
    let frameRate: Float
    let codec: String
    let fileSize: Int64
    let isCompatible: Bool
    let warnings: [String]
    let thumbnail: NSImage?

    var hasWarnings: Bool { !warnings.isEmpty }
    var isLargeFile: Bool { fileSize > 2_000_000_000 }

    var resolutionString: String {
        "\(Int(resolution.width)) × \(Int(resolution.height))"
    }

    var fileSizeString: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}
