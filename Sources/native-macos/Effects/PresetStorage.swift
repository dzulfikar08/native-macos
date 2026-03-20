// native-macos/Sources/native-macos/Effects/PresetStorage.swift
import Foundation

/// Persists custom presets to disk
struct PresetStorage {
    private let presetsDirectory: URL

    init(directory: URL? = nil) {
        if let directory = directory {
            presetsDirectory = directory
        } else {
            let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            presetsDirectory = supportDir.appendingPathComponent("OpenScreen/Presets", isDirectory: true)

            // Create directory if needed
            try? FileManager.default.createDirectory(at: presetsDirectory, withIntermediateDirectories: true)
        }
    }

    /// Load all custom presets from disk
    func loadCustomPresets() throws -> [EffectPreset] {
        let files = try FileManager.default.contentsOfDirectory(at: presetsDirectory, includingPropertiesForKeys: nil)

        var presets: [EffectPreset] = []
        for file in files where file.pathExtension == "json" {
            let data = try Data(contentsOf: file)
            let preset = try JSONDecoder().decode(EffectPreset.self, from: data)
            presets.append(preset)
        }

        return presets
    }

    /// Save a preset to disk
    func savePreset(_ preset: EffectPreset) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(preset)

        let fileName = preset.name.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "preset"
        let fileURL = presetsDirectory.appendingPathComponent("\(fileName).json")

        try data.write(to: fileURL)
    }

    /// Delete a preset from disk
    func deletePreset(_ preset: EffectPreset) throws {
        guard !preset.isBuiltIn else {
            throw PresetError.cannotModifyBuiltIn
        }

        let fileName = preset.name.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "preset"
        let fileURL = presetsDirectory.appendingPathComponent("\(fileName).json")

        try FileManager.default.removeItem(at: fileURL)
    }
}
