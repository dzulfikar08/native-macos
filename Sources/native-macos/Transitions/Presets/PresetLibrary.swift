import Foundation
import CoreMedia
import Combine

/// Manages in-memory collection of all presets (built-in + custom)
@MainActor
final class PresetLibrary: ObservableObject {

    /// All presets (built-in + custom)
    private(set) var allPresets: [TransitionPreset] = []

    /// Folder organization
    private(set) var folders: Set<String> = ["My Transitions"]

    /// Storage for persistence
    private let storage: TransitionPresetStorage

    /// Initialize library with built-in presets
    init(storage: TransitionPresetStorage = TransitionPresetStorage()) {
        self.storage = storage
        // Load built-in presets
        self.allPresets = BuiltInPresets.presets
    }

    /// Load custom presets from storage
    func loadCustomPresets() throws {
        let customPresets = try storage.loadCustomPresets()
        allPresets.append(contentsOf: customPresets)

        // Extract folders from custom presets
        for preset in customPresets {
            if !preset.folder.isEmpty {
                folders.insert(preset.folder)
            }
        }
    }

    /// Save a new custom preset
    func savePreset(
        name: String,
        folder: String,
        transition: TransitionClip,
        isFavorite: Bool
    ) throws {
        // Validate name
        try validatePresetName(name)

        // Create preset
        let preset = TransitionPreset(
            name: name,
            folder: folder,
            isFavorite: isFavorite,
            isBuiltIn: false,
            transitionType: transition.type,
            parameters: transition.parameters,
            duration: transition.duration
        )

        // Save to storage
        try storage.savePreset(preset)

        // Add to in-memory collection
        allPresets.append(preset)

        // Update folders
        if !folder.isEmpty {
            folders.insert(folder)
        }
    }

    /// Delete a custom preset
    func deletePreset(_ preset: TransitionPreset) throws {
        guard !preset.isBuiltIn else {
            throw PresetError.cannotModifyBuiltIn
        }

        try storage.deletePreset(preset)

        // Remove from in-memory collection
        allPresets.removeAll { $0.id == preset.id }
    }

    /// Update preset metadata
    func updatePreset(
        _ preset: TransitionPreset,
        name: String? = nil,
        folder: String? = nil
    ) {
        guard !preset.isBuiltIn else {
            return
        }

        // Find and update preset
        if let index = allPresets.firstIndex(where: { $0.id == preset.id }) {
            let updatedPreset = TransitionPreset(
                id: preset.id,
                name: name ?? preset.name,
                folder: folder ?? preset.folder,
                isFavorite: preset.isFavorite,
                isBuiltIn: preset.isBuiltIn,
                transitionType: preset.transitionType,
                parameters: preset.parameters,
                duration: preset.duration
            )

            allPresets[index] = updatedPreset

            // Save updated preset
            try? storage.savePreset(updatedPreset)
        }
    }

    /// Toggle favorite status
    func toggleFavorite(_ preset: TransitionPreset) {
        guard !preset.isBuiltIn else { return }

        if let index = allPresets.firstIndex(where: { $0.id == preset.id }) {
            let updatedPreset = TransitionPreset(
                id: preset.id,
                name: preset.name,
                folder: preset.folder,
                isFavorite: !preset.isFavorite,
                isBuiltIn: preset.isBuiltIn,
                transitionType: preset.transitionType,
                parameters: preset.parameters,
                duration: preset.duration
            )

            allPresets[index] = updatedPreset

            // Save updated preset
            try? storage.savePreset(updatedPreset)
        }
    }

    /// Get presets in a specific folder
    func presetsInFolder(_ folder: String) -> [TransitionPreset] {
        if folder == "All" {
            return allPresets
        } else if folder == "Favorites" {
            return favoritePresets()
        } else {
            return allPresets.filter { $0.folder == folder }
        }
    }

    /// Get favorite presets
    func favoritePresets() -> [TransitionPreset] {
        return allPresets.filter { $0.isFavorite }
    }

    /// Import preset from file
    func importPreset(from url: URL, into folder: String = "Imported") throws {
        let data = try Data(contentsOf: url)
        var preset = try JSONDecoder().decode(TransitionPreset.self, from: data)

        // Check for name collision
        if allPresets.contains(where: { $0.name == preset.name && $0.isBuiltIn }) {
            // Name collision with built-in - force rename
            preset = TransitionPreset(
                id: UUID(),
                name: "\(preset.name) (Imported)",
                folder: folder,
                isFavorite: false,
                isBuiltIn: false,
                transitionType: preset.transitionType,
                parameters: preset.parameters,
                duration: preset.duration
            )
        } else if allPresets.contains(where: { $0.name == preset.name && !$0.isBuiltIn }) {
            // Name collision with custom - force rename
            preset = TransitionPreset(
                id: UUID(),
                name: "\(preset.name) (Imported)",
                folder: folder,
                isFavorite: false,
                isBuiltIn: false,
                transitionType: preset.transitionType,
                parameters: preset.parameters,
                duration: preset.duration
            )
        } else {
            // No collision - just update folder
            preset = TransitionPreset(
                id: preset.id,
                name: preset.name,
                folder: folder,
                isFavorite: false,
                isBuiltIn: false,
                transitionType: preset.transitionType,
                parameters: preset.parameters,
                duration: preset.duration
            )
        }

        try storage.savePreset(preset)
        allPresets.append(preset)

        if !folder.isEmpty {
            folders.insert(folder)
        }
    }

    /// Export preset to file
    func exportPreset(_ preset: TransitionPreset, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(preset)
        try data.write(to: url)
    }

    /// Validate preset name
    func validatePresetName(_ name: String) throws {
        guard !name.isEmpty else {
            throw PresetError.emptyName
        }

        // Check for collision with built-in presets
        let builtInNames = Set(BuiltInPresets.presets.map { $0.name })
        if builtInNames.contains(name) {
            throw PresetError.reservedName
        }

        // Check for collision with existing custom presets
        if allPresets.contains(where: { $0.name == name && !$0.isBuiltIn }) {
            throw PresetError.duplicateName(name)
        }
    }
}
