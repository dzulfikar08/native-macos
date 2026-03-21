import Foundation
import CoreMedia

/// A transition between two clips in the timeline
struct TransitionClip: Codable, Sendable, Equatable {
    /// Unique identifier for this transition
    let id: UUID

    /// Type of transition effect
    let type: TransitionType

    /// Duration of the transition effect
    let duration: CMTime

    /// ID of the clip before the transition
    let leadingClipID: UUID

    /// ID of the clip after the transition
    let trailingClipID: UUID

    /// Parameters specific to the transition type
    let parameters: TransitionParameters

    /// Whether the transition is currently active
    let isEnabled: Bool

    /// Initialize a new transition clip with all parameters
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - type: Type of transition
    ///   - duration: Duration of the transition (must be positive)
    ///   - leadingClipID: ID of the clip before the transition
    ///   - trailingClipID: ID of the clip after the transition
    ///   - parameters: Parameters for the transition (defaults to type's default)
    ///   - isEnabled: Whether the transition is active (defaults to true)
    init(
        id: UUID = UUID(),
        type: TransitionType,
        duration: CMTime,
        leadingClipID: UUID,
        trailingClipID: UUID,
        parameters: TransitionParameters? = nil,
        isEnabled: Bool = true
    ) {
        precondition(duration.seconds > 0, "Transition duration must be positive")

        self.id = id
        self.type = type
        self.duration = duration
        self.leadingClipID = leadingClipID
        self.trailingClipID = trailingClipID
        self.parameters = parameters ?? TransitionParameters.default(for: type)
        self.isEnabled = isEnabled
    }

    /// Initialize a new transition clip with default parameters for the type
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - type: Type of transition (duration defaults to type's default)
    ///   - leadingClipID: ID of the clip before the transition
    ///   - trailingClipID: ID of the clip after the transition
    ///   - isEnabled: Whether the transition is active (defaults to true)
    init(
        id: UUID = UUID(),
        type: TransitionType,
        leadingClipID: UUID,
        trailingClipID: UUID,
        isEnabled: Bool = true
    ) {
        let defaultDuration = CMTime(seconds: type.defaultDuration, preferredTimescale: 600)
        self.init(
            id: id,
            type: type,
            duration: defaultDuration,
            leadingClipID: leadingClipID,
            trailingClipID: trailingClipID,
            parameters: nil,
            isEnabled: isEnabled
        )
    }

    /// Duration in seconds (convenience property)
    var durationInSeconds: Double {
        return duration.seconds
    }

    /// Validates that the transition is properly configured
    var isValid: Bool {
        return duration.seconds > 0 &&
               parameters.isValid &&
               leadingClipID != trailingClipID
    }

    /// Returns a new transition with the specified type
    func withType(_ newType: TransitionType) -> TransitionClip {
        TransitionClip(
            id: id,
            type: newType,
            duration: duration,
            leadingClipID: leadingClipID,
            trailingClipID: trailingClipID,
            parameters: TransitionParameters.default(for: newType),
            isEnabled: isEnabled
        )
    }

    /// Returns a new transition with the specified duration
    func withDuration(_ newDuration: CMTime) -> TransitionClip {
        precondition(newDuration.seconds > 0, "Transition duration must be positive")
        return TransitionClip(
            id: id,
            type: type,
            duration: newDuration,
            leadingClipID: leadingClipID,
            trailingClipID: trailingClipID,
            parameters: parameters,
            isEnabled: isEnabled
        )
    }

    /// Returns a new transition with the specified parameters
    func withParameters(_ newParameters: TransitionParameters) -> TransitionClip {
        TransitionClip(
            id: id,
            type: type,
            duration: duration,
            leadingClipID: leadingClipID,
            trailingClipID: trailingClipID,
            parameters: newParameters,
            isEnabled: isEnabled
        )
    }

    /// Returns a new transition with the enabled state toggled
    func toggled() -> TransitionClip {
        TransitionClip(
            id: id,
            type: type,
            duration: duration,
            leadingClipID: leadingClipID,
            trailingClipID: trailingClipID,
            parameters: parameters,
            isEnabled: !isEnabled
        )
    }

    /// Returns a new transition with the specified enabled state
    func withEnabled(_ enabled: Bool) -> TransitionClip {
        TransitionClip(
            id: id,
            type: type,
            duration: duration,
            leadingClipID: leadingClipID,
            trailingClipID: trailingClipID,
            parameters: parameters,
            isEnabled: enabled
        )
    }

    /// Explicit Equatable conformance
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
