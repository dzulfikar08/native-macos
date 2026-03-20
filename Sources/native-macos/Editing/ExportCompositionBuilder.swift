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
    /// - Parameter editorState: The editor state
    /// - Returns: Video composition for export
    /// - Throws: ExportError if composition cannot be built or is invalid
    func buildForExport(from editorState: EditorState) async throws -> AVVideoComposition {
        // Build base composition
        guard let composition = try compositionBuilder.buildComposition(for: editorState) else {
            throw ExportError.noVideoTracks
        }

        // Validate composition has instructions
        guard !composition.instructions.isEmpty else {
            throw ExportError.emptyComposition
        }

        return composition
    }
}

