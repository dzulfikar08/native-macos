import Foundation
import CoreMedia
import CoreGraphics

/// Caches layout information for transitions on the timeline
@MainActor
final class TransitionLayoutCache {
    /// Cached transition frames by transition ID
    private var frameCache: [UUID: CGRect] = [:]

    /// Width of the transition in pixels (for drag handles)
    let transitionRenderWidth: CGFloat = 60

    /// Height multiplier for transition overlay (relative to clip height)
    let transitionHeightMultiplier: CGFloat = 0.4

    /// Size of drag handles in pixels
    let dragHandleSize: CGFloat = 10

    /// Invalidates cached frame for a specific transition
    func invalidateTransition(transitionID: UUID) {
        frameCache.removeValue(forKey: transitionID)
    }

    /// Invalidates all cached frames
    func invalidateAll() {
        frameCache.removeAll()
    }

    /// Calculates and caches the frame for a transition
    /// - Parameters:
    ///   - transition: The transition to calculate frame for
    ///   - track: The track containing the transition
    ///   - clipLayoutCache: Cache for clip positions
    /// - Returns: The frame rectangle for the transition
    func transitionFrame(
        for transition: TransitionClip,
        in track: ClipTrack,
        clipLayoutCache: ClipLayoutCache
    ) -> CGRect? {
        // Check cache first
        if let cached = frameCache[transition.id] {
            return cached
        }

        // Get frames for leading and trailing clips
        guard
            let leadingClip = track.clips.first(where: { $0.id == transition.leadingClipID }),
            let trailingClip = track.clips.first(where: { $0.id == transition.trailingClipID }),
            let leadingFrame = clipLayoutCache.cachedLayout(for: leadingClip),
            let trailingFrame = clipLayoutCache.cachedLayout(for: trailingClip)
        else {
            return nil
        }

        // Calculate overlap region between leading and trailing clips
        // Transition is centered in the overlap, with a maximum render width
        let overlapStart = max(leadingFrame.minX, trailingFrame.minX)
        let overlapEnd = min(leadingFrame.maxX, trailingFrame.maxX)
        let overlapWidth = overlapEnd - overlapStart

        // Transition is centered in the overlap
        let transitionWidth = min(overlapWidth, transitionRenderWidth)
        let transitionX = overlapStart + (overlapWidth - transitionWidth) / 2

        // Transition height is a fraction of clip height
        let transitionHeight = leadingFrame.height * transitionHeightMultiplier
        let transitionY = leadingFrame.midY - transitionHeight / 2

        let frame = CGRect(x: transitionX, y: transitionY, width: transitionWidth, height: transitionHeight)

        // Cache the result
        frameCache[transition.id] = frame

        return frame
    }

    /// Calculates frame for drag handle
    /// - Parameters:
    ///   - transition: The transition
    ///   - edge: Which edge to calculate handle for
    ///   - track: The track containing the transition
    ///   - clipLayoutCache: Cache for clip positions
    /// - Returns: The frame for the drag handle
    func dragHandleFrame(
        for transition: TransitionClip,
        edge: TimelineViewModel.TransitionEdge,
        in track: ClipTrack,
        clipLayoutCache: ClipLayoutCache
    ) -> CGRect? {
        guard let transitionFrame = transitionFrame(for: transition, in: track, clipLayoutCache: clipLayoutCache) else {
            return nil
        }

        switch edge {
        case .leading:
            return CGRect(
                x: transitionFrame.minX - dragHandleSize / 2,
                y: transitionFrame.minY,
                width: dragHandleSize,
                height: transitionFrame.height
            )

        case .trailing:
            return CGRect(
                x: transitionFrame.maxX - dragHandleSize / 2,
                y: transitionFrame.minY,
                width: dragHandleSize,
                height: transitionFrame.height
            )
        }
    }

    /// Returns cached layout for a transition
    func cachedLayout(for transition: TransitionClip) -> CGRect? {
        return frameCache[transition.id]
    }
}
