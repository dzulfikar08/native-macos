import AVFoundation
import CoreMedia
import Foundation

/// Builds video compositions for export
@MainActor
final class ExportCompositionBuilder {

    private let compositionBuilder: AVVideoCompositionBuilder

    init() {
        self.compositionBuilder = AVVideoCompositionBuilder()
    }

    /// Builds a video composition for export from editor state
    /// - Parameters:
    ///   - editorState: The editor state
    ///   - quality: Quality settings for export (default: .good)
    /// - Returns: Video composition for export
    /// - Throws: ExportError if composition cannot be built or is invalid
    func buildForExport(
        from editorState: EditorState,
        quality: ExportQualitySettings = .good
    ) async throws -> AVVideoComposition {
        // Build base composition with quality settings
        guard let composition = try compositionBuilder.buildComposition(for: editorState, quality: quality) else {
            throw ExportError.noVideoTracks
        }

        // Validate composition has instructions
        guard !composition.instructions.isEmpty else {
            throw ExportError.emptyComposition
        }

        return composition
    }
}

