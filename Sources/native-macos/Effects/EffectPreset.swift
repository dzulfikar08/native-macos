// native-macos/Sources/native-macos/Effects/EffectPreset.swift
import Foundation
import AVFoundation

/// Effect preset for saving/sharing effect configurations
struct EffectPreset: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    var name: String
    var isBuiltIn: Bool
    var videoEffects: [VideoEffect]
    var audioEffects: [AudioEffect]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        isBuiltIn: Bool,
        videoEffects: [VideoEffect] = [],
        audioEffects: [AudioEffect] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.isBuiltIn = isBuiltIn
        self.videoEffects = videoEffects
        self.audioEffects = audioEffects
        self.createdAt = createdAt
    }
}

/// Effect stack container
struct EffectStack: Codable, Sendable {
    var videoEffects: [VideoEffect] = []
    var audioEffects: [AudioEffect] = []
    var selectedPreset: EffectPreset?

    /// Built-in presets
    static let builtInPresets: [EffectPreset] = [
        EffectPreset(
            name: "Warm",
            isBuiltIn: true,
            videoEffects: [
                VideoEffect(type: .saturation, parameters: .saturation(1.2)),
                VideoEffect(type: .contrast, parameters: .contrast(1.1))
            ]
        ),
        EffectPreset(
            name: "Cool",
            isBuiltIn: true,
            videoEffects: [
                VideoEffect(type: .saturation, parameters: .saturation(0.9)),
                VideoEffect(type: .brightness, parameters: .brightness(0.1))
            ]
        ),
        EffectPreset(
            name: "Vivid",
            isBuiltIn: true,
            videoEffects: [
                VideoEffect(type: .saturation, parameters: .saturation(1.4)),
                VideoEffect(type: .contrast, parameters: .contrast(1.2))
            ]
        ),
        EffectPreset(
            name: "Dramatic",
            isBuiltIn: true,
            videoEffects: [
                VideoEffect(type: .contrast, parameters: .contrast(1.5)),
                VideoEffect(type: .saturation, parameters: .saturation(1.3))
            ]
        ),
        EffectPreset(
            name: "Black & White",
            isBuiltIn: true,
            videoEffects: [
                VideoEffect(type: .saturation, parameters: .saturation(0.0)),
                VideoEffect(type: .contrast, parameters: .contrast(1.1))
            ]
        )
    ]

    /// Apply a preset to the effect stack
    mutating func applyPreset(_ preset: EffectPreset) {
        selectedPreset = preset
        videoEffects = preset.videoEffects
        audioEffects = preset.audioEffects
    }

    /// Save current effect stack as a custom preset
    mutating func saveAsPreset(name: String) throws {
        guard !name.isEmpty else {
            throw PresetError.emptyName
        }

        let newPreset = EffectPreset(
            name: name,
            isBuiltIn: false,
            videoEffects: videoEffects,
            audioEffects: audioEffects
        )

        selectedPreset = newPreset
    }
}

/// Preset errors
enum PresetError: LocalizedError {
    case emptyName
    case duplicateName(String)
    case tooManyPresets(Int)
    case cannotModifyBuiltIn
    case reservedName
    case saveFailed(reason: String)
    case diskFull
    case invalidFile
    case incompatibleVersion
    case thumbnailGenerationFailed

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Preset name cannot be empty"
        case .duplicateName(let name):
            return "A preset named '\(name)' already exists"
        case .tooManyPresets(let max):
            return "Maximum \(max) custom presets allowed"
        case .cannotModifyBuiltIn:
            return "Cannot modify built-in presets"
        case .reservedName:
            return "This name is reserved for built-in presets"
        case .saveFailed(let reason):
            return "Failed to save preset: \(reason)"
        case .diskFull:
            return "Not enough disk space to save preset"
        case .invalidFile:
            return "The selected file is not a valid preset"
        case .incompatibleVersion:
            return "This preset is from an incompatible version"
        case .thumbnailGenerationFailed:
            return "Failed to generate preset thumbnail"
        }
    }
}
