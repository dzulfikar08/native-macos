import AVFoundation
import Foundation

/// Orchestrates video export with transition effects
@MainActor
final class TransitionExportPipeline {

    private let editorState: EditorState
    private let compositionBuilder: ExportCompositionBuilder

    init(editorState: EditorState) {
        self.editorState = editorState
        self.compositionBuilder = ExportCompositionBuilder()
    }

    /// Exports the timeline with transitions applied
    /// - Parameter outputURL: Where to save the exported video
    func export(to outputURL: URL) async throws {
        // Build composition with transitions
        let composition = try await compositionBuilder.buildForExport(from: editorState)

        // Create exporter
        guard let asset = editorState.asset else {
            throw ExportError.noVideoTracks
        }

        let exporter = VideoExporter(
            asset: asset,
            outputURL: outputURL
        )

        // Apply composition
        exporter.setVideoComposition(composition)

        // Export
        try await exporter.startExport()
    }
}
