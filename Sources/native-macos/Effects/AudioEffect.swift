// AudioEffect data model with type-safe parameters
import Foundation
import AVFoundation

/// Audio effect type
enum AudioEffectType: String, Codable, Sendable {
    case volumeNormalization
    case equalizer
}

/// Type-safe audio effect parameters
enum AudioEffectParameters: Equatable, Codable, Sendable {
    case volumeNormalization(targetLUFS: Double)
    case equalizer(bass: Double, treble: Double)

    // MARK: - Validation Constants

    /// Minimum valid target LUFS value
    static let minTargetLUFS: Double = -60.0

    /// Maximum valid target LUFS value
    static let maxTargetLUFS: Double = 0.0

    /// Minimum valid gain value for equalizer (in dB)
    static let minGain: Double = -12.0

    /// Maximum valid gain value for equalizer (in dB)
    static let maxGain: Double = 12.0

    /// Default timescale for CMTime values
    static let defaultTimescale: CMTimeScale = 600

    // MARK: - Validation

    var isValid: Bool {
        switch self {
        case .volumeNormalization(let targetLUFS):
            return targetLUFS >= Self.minTargetLUFS && targetLUFS <= Self.maxTargetLUFS
        case .equalizer(let bass, let treble):
            return bass >= Self.minGain && bass <= Self.maxGain &&
                   treble >= Self.minGain && treble <= Self.maxGain
        }
    }

    // MARK: - Factory Methods

    static func withVolumeNormalization(_ targetLUFS: Double) -> Self {
        .volumeNormalization(targetLUFS: targetLUFS)
    }

    static func withEqualizer(bass: Double, treble: Double) -> Self {
        .equalizer(bass: bass, treble: treble)
    }
}

/// Audio effect data model
struct AudioEffect: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    var type: AudioEffectType
    var parameters: AudioEffectParameters
    var isEnabled: Bool
    var timeRange: ClosedRange<CMTime>?

    init(
        id: UUID = UUID(),
        type: AudioEffectType,
        parameters: AudioEffectParameters,
        isEnabled: Bool = true,
        timeRange: ClosedRange<CMTime>? = nil
    ) {
        self.id = id
        self.type = type
        self.parameters = parameters
        self.isEnabled = isEnabled
        self.timeRange = timeRange
    }
}

/// Audio effect errors
enum AudioEffectError: LocalizedError {
    case gainOutOfRange(String)
    case frequencyOutOfRange
    case targetLUFSOutOfRange(String)
    case parameterMismatch(String)
    case invalidTimeRange(String)

    var errorDescription: String? {
        switch self {
        case .gainOutOfRange(let message):
            return "Gain must be between \(AudioEffectParameters.minGain) dB and \(AudioEffectParameters.maxGain) dB: \(message)"
        case .frequencyOutOfRange:
            return "Frequency adjustment out of range"
        case .targetLUFSOutOfRange(let message):
            return "Target LUFS must be between \(AudioEffectParameters.minTargetLUFS) and \(AudioEffectParameters.maxTargetLUFS): \(message)"
        case .parameterMismatch(let msg):
            return "Parameter mismatch: \(msg)"
        case .invalidTimeRange(let message):
            return "Invalid time range: \(message)"
        }
    }
}

/// Audio effect validator
struct AudioEffectValidator {

    /// Validates an audio effect
    /// - Parameter effect: The audio effect to validate
    /// - Throws: AudioEffectError if validation fails
    func validate(_ effect: AudioEffect) throws {
        // Validate type-parameter matching
        switch (effect.type, effect.parameters) {
        case (.volumeNormalization, .volumeNormalization),
             (.equalizer, .equalizer):
            break  // Valid match
        default:
            throw AudioEffectError.parameterMismatch(
                "Type '\(effect.type)' does not match parameter type '\(type(of: effect.parameters))'"
            )
        }

        // Validate parameter values
        if !effect.parameters.isValid {
            switch effect.parameters {
            case .volumeNormalization(let targetLUFS):
                throw AudioEffectError.targetLUFSOutOfRange(
                    "Got \(targetLUFS), expected between \(AudioEffectParameters.minTargetLUFS) and \(AudioEffectParameters.maxTargetLUFS)"
                )
            case .equalizer(let bass, let treble):
                if bass < AudioEffectParameters.minGain || bass > AudioEffectParameters.maxGain {
                    throw AudioEffectError.gainOutOfRange(
                        "Bass gain \(bass) dB is out of range"
                    )
                }
                if treble < AudioEffectParameters.minGain || treble > AudioEffectParameters.maxGain {
                    throw AudioEffectError.gainOutOfRange(
                        "Treble gain \(treble) dB is out of range"
                    )
                }
            }
        }

        // Validate time range if present
        if let timeRange = effect.timeRange {
            try validateTimeRange(timeRange)
        }
    }

    /// Validates a time range
    /// - Parameter timeRange: The time range to validate
    /// - Throws: AudioEffectError if validation fails
    private func validateTimeRange(_ timeRange: ClosedRange<CMTime>) throws {
        let lowerBound = timeRange.lowerBound
        let upperBound = timeRange.upperBound

        // Check for non-negative values
        if lowerBound.seconds < 0 || upperBound.seconds < 0 {
            throw AudioEffectError.invalidTimeRange(
                "Time values must be non-negative (got \(lowerBound.seconds)s to \(upperBound.seconds)s)"
            )
        }

        // Check that lowerBound < upperBound
        if lowerBound.seconds >= upperBound.seconds {
            throw AudioEffectError.invalidTimeRange(
                "lowerBound (\(lowerBound.seconds)s) must be less than upperBound (\(upperBound.seconds)s)"
            )
        }
    }
}
