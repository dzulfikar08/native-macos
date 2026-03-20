import Foundation
import CoreMedia
import CoreGraphics
import Metal

struct TimelineTrack: Identifiable, Equatable, Sendable {
    let id: UUID
    let type: TrackType
    let name: String
    var height: CGFloat

    enum TrackType: Equatable, Sendable {
        case video
        case audio
    }
}

struct Thumbnail: Identifiable, Equatable, @unchecked Sendable {
    let id: UUID
    let time: CMTime
    let texture: MTLTexture?
    let isLoading: Bool

    // MTLTexture is not Sendable, but we only access it on @MainActor
    // Using @unchecked Sendable since we enforce thread safety via MainActor

    static func == (lhs: Thumbnail, rhs: Thumbnail) -> Bool {
        lhs.id == rhs.id &&
        lhs.time == rhs.time &&
        lhs.isLoading == rhs.isLoading
        // Note: We intentionally don't compare texture since MTLTexture doesn't conform to Equatable
        // and we care more about logical equality (same time, same loading state)
    }
}

struct TrackLayout: Equatable, Sendable {
    let track: TimelineTrack
    let frame: CGRect
    let thumbnailPositions: [CMTime: CGFloat]
}

enum TimelineError: LocalizedError, Sendable {
    case videoNotLoaded
    case invalidTimeRange
    case thumbnailGenerationFailed(time: CMTime)
    case waveformGenerationFailed
    case seekFailed

    var errorDescription: String? {
        switch self {
        case .videoNotLoaded:
            return "No video is currently loaded"
        case .invalidTimeRange:
            return "Invalid time range specified"
        case .thumbnailGenerationFailed(let time):
            return "Failed to generate thumbnail at time \(CMTimeGetSeconds(time))"
        case .waveformGenerationFailed:
            return "Failed to generate audio waveform"
        case .seekFailed:
            return "Failed to seek to specified time"
        }
    }
}
