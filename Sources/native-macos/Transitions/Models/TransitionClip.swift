import Foundation
import CoreMedia

/// Represents a transition between two video clips
struct TransitionClip: Identifiable, Equatable, Codable, Sendable {
    /// Unique identifier for this transition
    let id: UUID

    /// Type of transition effect
    var type: TransitionType

    /// Duration of the transition effect
    var duration: CMTime

    /// ID of the clip before the transition
    let leadingClipID: UUID

    /// ID of the clip after the transition
    let trailingClipID: UUID

    /// Type-safe parameters for the transition
    var parameters: TransitionParameters

    /// Whether the transition is currently enabled
    var isEnabled: Bool

    /// Creates a new transition
    init(
        id: UUID = UUID(),
        type: TransitionType,
        duration: CMTime,
        leadingClipID: UUID,
        trailingClipID: UUID,
        parameters: TransitionParameters,
        isEnabled: Bool = true
    ) {
        // Validate duration is positive
        precondition(duration.isValid && duration > .zero, "Transition duration must be positive")

        self.id = id
        self.type = type
        self.duration = duration
        self.leadingClipID = leadingClipID
        self.trailingClipID = trailingClipID
        self.parameters = parameters
        self.isEnabled = isEnabled
    }

    /// Creates a transition with default parameters for the given type
    init(
        id: UUID = UUID(),
        type: TransitionType,
        duration: CMTime,
        leadingClipID: UUID,
        trailingClipID: UUID,
        isEnabled: Bool = true
    ) {
        self.init(
            id: id,
            type: type,
            duration: duration,
            leadingClipID: leadingClipID,
            trailingClipID: trailingClipID,
            parameters: .default(for: type),
            isEnabled: isEnabled
        )
    }

    /// Duration in seconds (convenience accessor)
    var durationInSeconds: Double {
        return CMTimeGetSeconds(duration)
    }

    /// Validates this transition is internally consistent
    var isValid: Bool {
        return duration.isValid && duration > .zero && parameters.isValid
    }

    /// Returns a copy with updated type and default parameters
    func withType(_ newType: TransitionType) -> TransitionClip {
        var copy = self
        copy.type = newType
        copy.parameters = .default(for: newType)
        return copy
    }

    /// Returns a copy with updated duration
    func withDuration(_ newDuration: CMTime) -> TransitionClip {
        var copy = self
        copy.duration = newDuration
        return copy
    }

    /// Returns a copy with updated parameters
    func withParameters(_ newParameters: TransitionParameters) -> TransitionClip {
        var copy = self
        copy.parameters = newParameters
        return copy
    }

    /// Returns a copy with enabled state toggled
    func toggled() -> TransitionClip {
        var copy = self
        copy.isEnabled = !copy.isEnabled
        return copy
    }
}

/// Explicit Equatable conformance for CMTime comparison
extension TransitionClip {
    static func == (lhs: TransitionClip, rhs: TransitionClip) -> Bool {
        return lhs.id == rhs.id &&
               lhs.type == rhs.type &&
               lhs.duration == rhs.duration &&
               lhs.leadingClipID == rhs.leadingClipID &&
               lhs.trailingClipID == rhs.trailingClipID &&
               lhs.parameters == rhs.parameters &&
               lhs.isEnabled == rhs.isEnabled
    }
}
