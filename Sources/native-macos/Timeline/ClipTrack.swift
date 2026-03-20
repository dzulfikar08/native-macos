import Foundation
import AppKit
import CoreMedia
import Combine

/// Track type enumeration
enum TrackType: String, Codable, Sendable {
    case video
    case audio
    case title
    case effects
}

/// Compositing mode for video tracks
enum CompositingMode: String, Codable, Sendable {
    case normal
    case add
    case multiply
    case screen
    case overlay
}

/// Container for ordered clips that share compositing and rendering properties
/// Note: Not Sendable due to @Published clips array. All access must remain on @MainActor.
@MainActor
class ClipTrack: Identifiable, ObservableObject {
    let id: UUID
    var name: String
    var type: TrackType

    /// Ordered clips on this track (sorted by timeRangeInTimeline.start)
    @Published var clips: [VideoClip] = []

    /// Track state
    var isEnabled: Bool = true {
        didSet { objectWillChange.send() }
    }
    var isLocked: Bool = false {
        didSet { objectWillChange.send() }
    }
    var isVisible: Bool = true {
        didSet { objectWillChange.send() }
    }

    /// Compositing properties (for video tracks)
    var opacity: Float = 1.0 {
        didSet { objectWillChange.send() }
    }
    var compositingMode: CompositingMode = .normal {
        didSet { objectWillChange.send() }
    }

    /// Audio properties (for audio tracks)
    var volume: Float = 1.0 {
        didSet { objectWillChange.send() }
    }
    var isAudioMuted: Bool = false {
        didSet { objectWillChange.send() }
    }

    /// Z-index for rendering order (lower = renders first/behind)
    var zIndex: Int = 0

    /// Track height in timeline UI
    var height: Double = 80.0

    init(
        id: UUID = UUID(),
        name: String,
        type: TrackType,
        zIndex: Int = 0
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.zIndex = zIndex
    }

    /// Add clip to track (maintains sorted order)
    func addClip(_ clip: VideoClip) {
        clips.append(clip)
        sortClips()
    }

    /// Remove clip from track
    func removeClip(id: UUID) {
        clips.removeAll { $0.id == id }
    }

    /// Find clip at timeline time
    func clip(at timelineTime: CMTime) -> VideoClip? {
        clips.first { clip in
            timelineTime >= clip.timeRangeInTimeline.start &&
            timelineTime < clip.timeRangeInTimeline.end
        }
    }

    /// Find all clips intersecting time range
    func clips(in range: CMTimeRange) -> [VideoClip] {
        clips.filter { clip in
            clip.timeRangeInTimeline.end > range.start &&
            clip.timeRangeInTimeline.start < range.end
        }
    }

    /// Maintain clips sorted by start time
    private func sortClips() {
        clips.sort { $0.timeRangeInTimeline.start < $1.timeRangeInTimeline.start }
    }
}
