import AVFoundation
import Foundation
import CoreMedia
import CoreImage
import Combine

/// A video clip on the timeline, wrapping an AVAsset with positioning information
/// Note: Not Sendable due to AVAsset. All access must remain on @MainActor.
@MainActor
class VideoClip: Identifiable, ObservableObject {
    let id: UUID
    var name: String {
        didSet { objectWillChange.send() }
    }

    /// The underlying AVAsset (URL or composition)
    /// Note: AVAsset is not Sendable, so VideoClip is @MainActor-bound
    let asset: AVAsset

    /// Portion of the source asset to use (e.g., trim start/end)
    var timeRangeInSource: CMTimeRange {
        didSet { objectWillChange.send() }
    }

    /// Where the clip appears on the timeline
    var timeRangeInTimeline: CMTimeRange {
        didSet { objectWillChange.send() }
    }

    /// Which track this clip belongs to
    var trackID: UUID {
        didSet { objectWillChange.send() }
    }

    /// Clip state
    var isEnabled: Bool = true {
        didSet { objectWillChange.send() }
    }
    var opacity: Float = 1.0 {
        didSet { objectWillChange.send() }
    }
    var speed: Float = 1.0 {
        didSet { objectWillChange.send() }
    }

    /// Audio properties
    var volume: Float = 1.0 {
        didSet { objectWillChange.send() }
    }
    var isAudioMuted: Bool = false {
        didSet { objectWillChange.send() }
    }

    /// Effects applied to this clip
    var videoEffects: [VideoEffect] = [] {
        didSet { objectWillChange.send() }
    }
    var audioEffects: [AudioEffect] = [] {
        didSet { objectWillChange.send() }
    }

    /// Clip metadata
    let createdAt: Date
    var modifiedAt: Date {
        didSet { objectWillChange.send() }
    }

    init(
        id: UUID = UUID(),
        name: String,
        asset: AVAsset,
        timeRangeInSource: CMTimeRange,
        timeRangeInTimeline: CMTimeRange,
        trackID: UUID,
        opacity: Float = 1.0,
        speed: Float = 1.0,
        volume: Float = 1.0
    ) {
        // Validate parameters
        precondition((0.0...1.0).contains(opacity), "Opacity must be in range [0.0, 1.0]")
        precondition((0.1...16.0).contains(speed), "Speed must be in range [0.1, 16.0]")
        precondition((0.0...2.0).contains(volume), "Volume must be in range [0.0, 2.0]")

        self.id = id
        self.name = name
        self.asset = asset
        self.timeRangeInSource = timeRangeInSource
        self.timeRangeInTimeline = timeRangeInTimeline
        self.trackID = trackID
        self.opacity = opacity
        self.speed = speed
        self.volume = volume
        self.createdAt = Date()
        self.modifiedAt = Date()
    }

    /// Duration of this clip on timeline (accounting for speed)
    var timelineDuration: CMTime {
        let sourceDuration = timeRangeInSource.duration
        return CMTimeMultiplyByFloat64(sourceDuration, multiplier: Float64(1.0 / speed))
    }

    /// Get frame from this clip at timeline time
    func frame(at timelineTime: CMTime) -> CIImage? {
        let clipTime = timelineTimeInSource(timelineTime)
        return extractFrame(from: asset, at: clipTime)
    }

    /// Convert timeline time to source asset time
    func timelineTimeInSource(_ timelineTime: CMTime) -> CMTime {
        let offset = timelineTime - timeRangeInTimeline.start
        let scaledOffset = CMTimeMultiplyByFloat64(offset, multiplier: Float64(speed))
        return timeRangeInSource.start + scaledOffset
    }

    /// Extract frame from asset at given time using AVAssetImageGenerator
    private func extractFrame(from asset: AVAsset, at time: CMTime) -> CIImage? {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        do {
            let image = try generator.copyCGImage(at: time, actualTime: nil)
            return CIImage(cgImage: image)
        } catch {
            // Asset may not have actual video content (test composition)
            return nil
        }
    }
}
