import Foundation
import CoreImage
import CoreMedia
import AppKit

/// Persists custom presets to disk
struct TransitionPresetStorage {

    private let presetsDirectory: URL

    init(directory: URL? = nil) {
        if let directory = directory {
            presetsDirectory = directory
        } else {
            let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            presetsDirectory = supportDir.appendingPathComponent("OpenScreen/TransitionPresets", isDirectory: true)

            // Create directory if needed
            try? FileManager.default.createDirectory(at: presetsDirectory, withIntermediateDirectories: true, attributes: nil)
        }
    }

    /// Load all custom presets from disk
    func loadCustomPresets() throws -> [TransitionPreset] {
        let files = try FileManager.default.contentsOfDirectory(at: presetsDirectory, includingPropertiesForKeys: nil)

        var presets: [TransitionPreset] = []
        for file in files where file.pathExtension == "json" {
            guard file.lastPathComponent != ".DS_Store" else { continue }
            let data = try Data(contentsOf: file)
            let preset = try JSONDecoder().decode(TransitionPreset.self, from: data)
            presets.append(preset)
        }

        return presets
    }

    /// Save a preset to disk
    func savePreset(_ preset: TransitionPreset) throws {
        guard !preset.isBuiltIn else {
            throw PresetError.cannotModifyBuiltIn
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(preset)

        // Sanitize filename: percent-encode name, add folder prefix if present
        let folderPrefix = preset.folder.isEmpty ? "" : "\(preset.folder) "
        let sanitizedName = preset.name.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? preset.name
        let fileName = "\(folderPrefix)\(sanitizedName).json"
        let fileURL = presetsDirectory.appendingPathComponent(fileName)

        try data.write(to: fileURL)
    }

    /// Delete a preset from disk (including thumbnail cleanup)
    func deletePreset(_ preset: TransitionPreset) throws {
        guard !preset.isBuiltIn else {
            throw PresetError.cannotModifyBuiltIn
        }

        // Delete preset JSON file
        let folderPrefix = preset.folder.isEmpty ? "" : "\(preset.folder) "
        let sanitizedName = preset.name.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? preset.name
        let fileName = "\(folderPrefix)\(sanitizedName).json"
        let fileURL = presetsDirectory.appendingPathComponent(fileName)

        try FileManager.default.removeItem(at: fileURL)

        // Delete thumbnail if exists
        try? deleteThumbnail(for: preset)
    }

    /// Save thumbnail for a preset
    func saveThumbnail(_ image: CIImage, for preset: TransitionPreset) throws {
        let thumbnailsDir = presetsDirectory.appendingPathComponent("Thumbnails", isDirectory: true)

        // Create thumbnails directory if needed
        try? FileManager.default.createDirectory(at: thumbnailsDir, withIntermediateDirectories: true, attributes: nil)

        // Generate filename
        let folderPrefix = preset.folder.isEmpty ? "" : "\(preset.folder) "
        let sanitizedName = preset.name.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? preset.name
        let fileName = "\(folderPrefix)\(sanitizedName).png"
        let fileURL = thumbnailsDir.appendingPathComponent(fileName)

        // Convert CIImage to CGImage then to PNG
        let rep = NSCIImageRep(ciImage: image)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)

        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw PresetError.thumbnailGenerationFailed
        }

        try pngData.write(to: fileURL)
    }

    /// Load thumbnail for a preset
    func loadThumbnail(for preset: TransitionPreset) throws -> CIImage? {
        let thumbnailsDir = presetsDirectory.appendingPathComponent("Thumbnails", isDirectory: false)

        let folderPrefix = preset.folder.isEmpty ? "" : "\(preset.folder) "
        let sanitizedName = preset.name.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? preset.name
        let fileName = "\(folderPrefix)\(sanitizedName).png"
        let fileURL = thumbnailsDir.appendingPathComponent(fileName)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        guard let image = NSImage(contentsOf: fileURL),
              let imageData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: imageData),
              let cgImage = bitmap.cgImage else {
            return nil
        }

        return CIImage(cgImage: cgImage)
    }

    /// Delete thumbnail for a preset
    private func deleteThumbnail(for preset: TransitionPreset) throws {
        let thumbnailsDir = presetsDirectory.appendingPathComponent("Thumbnails", isDirectory: false)

        let folderPrefix = preset.folder.isEmpty ? "" : "\(preset.folder) "
        let sanitizedName = preset.name.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? preset.name
        let fileName = "\(folderPrefix)\(sanitizedName).png"
        let fileURL = thumbnailsDir.appendingPathComponent(fileName)

        try? FileManager.default.removeItem(at: fileURL)
    }
}
