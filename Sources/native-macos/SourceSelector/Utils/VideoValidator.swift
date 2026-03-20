import Foundation
import AVFoundation
import UniformTypeIdentifiers
import CoreGraphics
import AppKit

/// Errors that can occur during video validation
enum VideoValidationError: LocalizedError {
    case fileNotFound(URL)
    case unsupportedFormat(String)
    case corruptedFile
    case tooLarge(Int64)
    case noVideoTrack

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "File not found: \(url.lastPathComponent)"
        case .unsupportedFormat(let format):
            return "Unsupported format: \(format)"
        case .corruptedFile:
            return "File appears to be corrupted"
        case .tooLarge(let size):
            let sizeGB = Double(size) / 1_000_000_000
            return "File is very large (\(String(format: "%.1f", sizeGB)) GB)"
        case .noVideoTrack:
            return "No video track found in file"
        }
    }
}

/// Validator for video files
struct VideoValidator {

    /// Validates a video file and extracts metadata
    static func validate(url: URL) -> Result<VideoMetadata, VideoValidationError> {
        // Check file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .failure(.fileNotFound(url))
        }

        // Check format support
        guard isSupportedFormat(url: url) else {
            return .failure(.unsupportedFormat(url.pathExtension))
        }

        // Load asset
        let asset = AVAsset(url: url)

        // Extract metadata
        let metadata = extractMetadata(from: asset, url: url)

        guard let metadata = metadata else {
            return .failure(.corruptedFile)
        }

        return .success(metadata)
    }

    /// Checks if file format is supported
    static func isSupportedFormat(url: URL) -> Bool {
        guard let uti = UTType(filenameExtension: url.pathExtension) else {
            return false
        }

        let supportedTypes: [UTType] = [
            .movie,
            .mpeg4Movie,
            .quickTimeMovie,
            .audiovisualContent
        ]

        return supportedTypes.contains { uti.conforms(to: $0) }
    }

    /// Extracts metadata from AVAsset
    /// Returns nil if:
    /// - No video track found (will trigger .noVideoTrack error)
    /// - File attributes unreadable (will trigger .corruptedFile error)
    private static func extractMetadata(from asset: AVAsset, url: URL) -> VideoMetadata? {
        // Get duration
        let duration = asset.duration
        let durationString = formatDuration(duration)

        // Get file size
        let fileSize: Int64
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            fileSize = attributes[.size] as? Int64 ?? 0
        } catch {
            // File attributes failure - will be treated as corrupted file
            return nil
        }

        // Get video track
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            // No video track - will trigger .noVideoTrack error
            return nil
        }

        // Get resolution
        let resolution = videoTrack.naturalSize.applying(videoTrack.preferredTransform)

        // Get frame rate
        let frameRate = videoTrack.nominalFrameRate

        // Get codec
        let codec: String
        if let formatDesc = videoTrack.formatDescriptions.first {
            // FourCC code as string
            let fourCC = CMFormatDescriptionGetMediaSubType(formatDesc as! CMFormatDescription)
            var result = FourCharCodeToString(fourCC)
            if result.isEmpty {
                result = "unknown"
            }
            codec = result
        } else {
            codec = "unknown"
        }

        // Check compatibility
        let (isCompatible, warnings) = checkCompatibility(tracks: asset.tracks)

        return VideoMetadata(
            duration: duration,
            durationString: durationString,
            resolution: resolution,
            frameRate: frameRate,
            codec: codec,
            fileSize: fileSize,
            isCompatible: isCompatible,
            warnings: warnings,
            thumbnail: nil
        )
    }

    /// Formats duration as HH:MM:SS
    private static func formatDuration(_ duration: CMTime) -> String {
        let totalSeconds = CMTimeGetSeconds(duration)
        let hours = Int(totalSeconds) / 3600
        let minutes = Int(totalSeconds) % 3600 / 60
        let seconds = Int(totalSeconds) % 60

        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    /// Checks if tracks are compatible
    private static func checkCompatibility(tracks: [AVAssetTrack]) -> (Bool, [String]) {
        var warnings: [String] = []

        // Check for variable frame rate
        if let videoTrack = tracks.first(where: { $0.mediaType == .video }) {
            if videoTrack.nominalFrameRate == 0 {
                warnings.append("Variable frame rate detected - playback may not be smooth")
            }
        }

        return (true, warnings)
    }

    /// Converts FourCharCode to String representation
    private static func FourCharCodeToString(_ code: FourCharCode) -> String {
        var result = ""
        for i: UInt32 in 0..<4 {
            let c = (code >> ((3 - i) * 8)) & 0xFF
            guard c >= 32 && c <= 126 else { return "" } // Only printable ASCII
            if let scalar = UnicodeScalar(c) {
                result.append(Character(scalar))
            }
        }
        return result
    }
}
