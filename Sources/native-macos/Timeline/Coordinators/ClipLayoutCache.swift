import Foundation
import CoreGraphics

/// Stub implementation for clip layout caching
/// This will be replaced with the full implementation from Phase 3.0.3
@MainActor
final class ClipLayoutCache {
    /// Returns cached layout for a clip (stub implementation)
    func cachedLayout(for clip: VideoClip) -> CGRect? {
        // Stub: always returns nil for now
        // Will be implemented in Phase 3.0.3
        return nil
    }

    /// Invalidates cached frame for a specific clip
    func invalidateClip(clipID: UUID) {
        // Stub: no-op for now
    }

    /// Invalidates all cached frames
    func invalidateAll() {
        // Stub: no-op for now
    }
}
