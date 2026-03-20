import Foundation
import CoreMedia

/// Factory for creating transitions with appropriate defaults
@MainActor
enum TransitionFactory {
    /// Creates a transition between two clips with default duration for the type
    /// - Parameters:
    ///   - type: Type of transition to create
    ///   - leadingClipID: ID of the leading (outgoing) clip
    ///   - trailingClipID: ID of the trailing (incoming) clip
    ///   - editorState: Editor state to calculate overlap
    /// - Returns: A transition if overlap is sufficient, nil otherwise
    static func createTransition(
        type: TransitionType,
        between leadingClipID: UUID,
        and trailingClipID: UUID,
        in editorState: EditorState
    ) -> TransitionClip? {
        // Calculate available overlap
        let overlap = editorState.calculateOverlap(
            between: leadingClipID,
            and: trailingClipID
        )

        // Use default duration for type, capped at available overlap
        let defaultDuration = defaultDuration(for: type)
        let duration = min(defaultDuration, overlap.duration)

        // Validate minimum duration
        guard duration >= TransitionValidator.minimumDuration else {
            return nil
        }

        return TransitionClip(
            type: type,
            duration: duration,
            leadingClipID: leadingClipID,
            trailingClipID: trailingClipID
        )
    }

    /// Returns the default duration for a transition type
    /// - Parameter type: The transition type
    /// - Returns: Default duration in seconds
    private static func defaultDuration(for type: TransitionType) -> CMTime {
        switch type {
        case .crossfade:
            return CMTime(seconds: 1.0, preferredTimescale: 600)
        case .fadeToColor:
            return CMTime(seconds: 0.5, preferredTimescale: 600)
        case .wipe:
            return CMTime(seconds: 0.75, preferredTimescale: 600)
        case .iris:
            return CMTime(seconds: 1.0, preferredTimescale: 600)
        case .blinds:
            return CMTime(seconds: 0.75, preferredTimescale: 600)
        case .custom:
            return CMTime(seconds: 1.0, preferredTimescale: 600)
        }
    }
}
