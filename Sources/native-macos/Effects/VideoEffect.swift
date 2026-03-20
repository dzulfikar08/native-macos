// native-macos/Sources/native-macos/Effects/VideoEffect.swift
import Foundation
import AVFoundation

/// Video effect type
enum VideoEffectType: String, Codable, Sendable {
    case brightness, contrast, saturation
}

/// Type-safe video effect parameters
enum VideoEffectParameters: Equatable, Codable, Sendable {
    /// Valid range for brightness parameter (-1.0 to 1.0)
    static let brightnessRange: ClosedRange<Double> = (-1.0...1.0)
    /// Valid range for contrast parameter (0.0 to 4.0)
    static let contrastRange: ClosedRange<Double> = (0.0...4.0)
    /// Valid range for saturation parameter (0.0 to 2.0)
    static let saturationRange: ClosedRange<Double> = (0.0...2.0)

    case brightness(value: Double)
    case contrast(value: Double)
    case saturation(value: Double)

    var value: Double {
        switch self {
        case .brightness(let v), .contrast(let v), .saturation(let v):
            return v
        }
    }

    var isValid: Bool {
        switch self {
        case .brightness(let v):
            return Self.brightnessRange.contains(v)
        case .contrast(let v):
            return Self.contrastRange.contains(v)
        case .saturation(let v):
            return Self.saturationRange.contains(v)
        }
    }

    static func brightness(_ value: Double) -> Self { .brightness(value: value) }
    static func contrast(_ value: Double) -> Self { .contrast(value: value) }
    static func saturation(_ value: Double) -> Self { .saturation(value: value) }
}

/// Video effect data model
struct VideoEffect: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    var type: VideoEffectType
    var parameters: VideoEffectParameters
    var isEnabled: Bool
    var timeRange: ClosedRange<CMTime>?

    init(
        id: UUID = UUID(),
        type: VideoEffectType,
        parameters: VideoEffectParameters,
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

/// Video effect errors
enum VideoEffectError: LocalizedError {
    case invalidParameter(String)
    case parameterOutOfRange(String, value: Double, min: Double, max: Double)
    case timeRangeOutOfBounds
    case parameterMismatch(String)

    var errorDescription: String? {
        switch self {
        case .invalidParameter(let param):
            return "Invalid parameter: \(param)"
        case .parameterOutOfRange(let param, let value, let min, let max):
            return "\(param) value \(value) is out of range. Must be between \(min) and \(max)"
        case .timeRangeOutOfBounds:
            return "Time range is invalid: lowerBound must be less than upperBound and both must be positive"
        case .parameterMismatch(let msg):
            return "Parameter mismatch: \(msg)"
        }
    }
}

/// Validates video effect parameters and type matching
struct VideoEffectValidator {
    func validate(_ effect: VideoEffect) throws {
        // Check parameter type matches effect type
        switch (effect.type, effect.parameters) {
        case (.brightness, .brightness),
             (.contrast, .contrast),
             (.saturation, .saturation):
            break  // Valid match
        default:
            throw VideoEffectError.parameterMismatch("Parameters don't match effect type")
        }

        // Validate parameter values
        guard effect.parameters.isValid else {
            switch effect.parameters {
            case .brightness(let value):
                throw VideoEffectError.parameterOutOfRange(
                    "brightness",
                    value: value,
                    min: VideoEffectParameters.brightnessRange.lowerBound,
                    max: VideoEffectParameters.brightnessRange.upperBound
                )
            case .contrast(let value):
                throw VideoEffectError.parameterOutOfRange(
                    "contrast",
                    value: value,
                    min: VideoEffectParameters.contrastRange.lowerBound,
                    max: VideoEffectParameters.contrastRange.upperBound
                )
            case .saturation(let value):
                throw VideoEffectError.parameterOutOfRange(
                    "saturation",
                    value: value,
                    min: VideoEffectParameters.saturationRange.lowerBound,
                    max: VideoEffectParameters.saturationRange.upperBound
                )
            }
        }

        // Validate time range if present
        if let timeRange = effect.timeRange {
            let lowerSeconds = CMTimeGetSeconds(timeRange.lowerBound)
            let upperSeconds = CMTimeGetSeconds(timeRange.upperBound)

            guard lowerSeconds >= 0 && upperSeconds > 0 else {
                throw VideoEffectError.timeRangeOutOfBounds
            }

            guard lowerSeconds < upperSeconds else {
                throw VideoEffectError.timeRangeOutOfBounds
            }
        }
    }
}
