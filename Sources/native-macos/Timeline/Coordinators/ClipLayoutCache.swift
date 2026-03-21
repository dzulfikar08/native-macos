import Foundation
import CoreGraphics
import CoreMedia

/// Layout information for a clip in the timeline
struct ClipLayout {
    /// ID of the clip
    let clipID: UUID

    /// Frame in timeline coordinates
    let frame: CGRect

    /// Time range in timeline
    let timeRange: CMTimeRange

    /// Whether layout needs recalculation
    let isDirty: Bool
}

/// Stub implementation for clip layout caching
/// This will be replaced with the full implementation from Phase 3.0.3
@MainActor
final class ClipLayoutCache {
    /// Cached clip layouts
    private var layouts: [UUID: ClipLayout] = [:]

    /// Returns cached layout for a clip
    func layout(for clipID: UUID) -> ClipLayout? {
        return layouts[clipID]
    }

    /// Registers a clip for layout tracking
    func register(_ clip: VideoClip) {
        // Create a default layout - will be calculated properly in Phase 3.0.3
        let layout = ClipLayout(
            clipID: clip.id,
            frame: .zero,
            timeRange: clip.timeRangeInTimeline,
            isDirty: true
        )
        layouts[clip.id] = layout
    }

    /// Returns cached layout for a clip (legacy method for compatibility)
    func cachedLayout(for clip: VideoClip) -> CGRect? {
        return layouts[clip.id]?.frame
    }

    /// Invalidates cached frame for a specific clip
    func invalidateClip(clipID: UUID) {
        layouts[clipID] = nil
    }

    /// Invalidates all cached frames
    func invalidateAll() {
        layouts.removeAll()
    }
}
