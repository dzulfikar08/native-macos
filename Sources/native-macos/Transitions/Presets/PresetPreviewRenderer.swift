import Foundation
import CoreImage
import CoreMedia
import AppKit
import Metal

/// Generates thumbnails for transition presets
struct PresetPreviewRenderer {

    /// Thumbnail size
    static let thumbnailSize = CGSize(width: 128, height: 72)

    /// In-memory thumbnail cache
    private var thumbnailCache: [UUID: CIImage] = [:]

    /// Generate thumbnail for a preset
    func generateThumbnail(for preset: TransitionPreset) throws -> CIImage {
        // Get renderer from context
        guard let renderer = TransitionRenderContext.shared.renderer(for: preset.transitionType) else {
            throw PresetError.thumbnailGenerationFailed
        }

        // Create test frames (solid colors: red leading, blue trailing)
        let leadingColor = CIColor(red: 1, green: 0, blue: 0)
        let trailingColor = CIColor(red: 0, green: 0, blue: 1)

        let leadingImage = CIImage(color: leadingColor).cropped(to: CGRect(x: 0, y: 0, width: 640, height: 480))
        let trailingImage = CIImage(color: trailingColor).cropped(to: CGRect(x: 0, y: 0, width: 640, height: 480))

        // Render at midpoint (progress = 0.5)
        let rendered = renderer.render(
            leading: leadingImage,
            trailing: trailingImage,
            parameters: preset.parameters,
            progress: 0.5
        )

        guard let thumbnail = rendered else {
            throw PresetError.thumbnailGenerationFailed
        }

        // Scale to thumbnail size
        let scaleX = Self.thumbnailSize.width / thumbnail.extent.width
        let scaleY = Self.thumbnailSize.height / thumbnail.extent.height
        let scale = min(scaleX, scaleY)

        let scaledThumbnail = thumbnail.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        return scaledThumbnail
    }

    /// Load or generate thumbnail (uses cache)
    mutating func thumbnail(
        for preset: TransitionPreset,
        storage: TransitionPresetStorage
    ) -> CIImage? {
        // Check cache first
        if let cached = thumbnailCache[preset.id] {
            return cached
        }

        // Try loading from disk
        if let loaded = try? storage.loadThumbnail(for: preset) {
            thumbnailCache[preset.id] = loaded
            return loaded
        }

        // Generate new thumbnail
        guard let generated = try? generateThumbnail(for: preset) else {
            // Return fallback icon
            return fallbackIcon(for: preset.transitionType)
        }

        // Save to disk
        try? storage.saveThumbnail(generated, for: preset)

        // Cache in memory
        thumbnailCache[preset.id] = generated

        return generated
    }

    /// Get fallback icon for transition type
    private func fallbackIcon(for type: TransitionType) -> CIImage? {
        // Create simple icon based on type
        let size = Self.thumbnailSize
        let baseColor: CIColor

        switch type {
        case .crossfade:
            baseColor = CIColor(red: 0.5, green: 0.5, blue: 0.5)
        case .fadeToColor:
            baseColor = CIColor(red: 0.2, green: 0.2, blue: 0.2)
        case .wipe:
            baseColor = CIColor(red: 0.3, green: 0.5, blue: 0.7)
        case .iris:
            baseColor = CIColor(red: 0.7, green: 0.3, blue: 0.5)
        case .blinds:
            baseColor = CIColor(red: 0.4, green: 0.6, blue: 0.4)
        case .custom:
            baseColor = CIColor(red: 0.6, green: 0.6, blue: 0.3)
        }

        return CIImage(color: baseColor).cropped(to: CGRect(origin: .zero, size: size))
    }
}
