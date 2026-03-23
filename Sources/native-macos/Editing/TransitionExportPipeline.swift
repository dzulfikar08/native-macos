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
    /// - Parameters:
    ///   - outputURL: Where to save the exported video
    ///   - quality: Quality settings for export (default: .good)
    func export(
        to outputURL: URL,
        quality: ExportQualitySettings = .good
    ) async throws {
        // Validate transitions before export
        try validateTransitions()

        // Build AVAsset composition
        let asset = try await buildAVAsset()

        // Build video composition with quality settings
        let composition = try await compositionBuilder.buildForExport(from: editorState, quality: quality)

        // Create and configure exporter
        let exporter = VideoExporter(asset: asset, outputURL: outputURL)
        exporter.setVideoComposition(composition)

        // Export
        try await exporter.startExport()
    }

    /// Creates AVAsset composition from editor state
    private func buildAVAsset() async throws -> AVMutableComposition {
        let composition = AVMutableComposition()

        // Add video tracks
        for track in editorState.clipTracks.filter({ $0.type == .video }) {
            let compositionTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )

            for clip in track.clips {
                // Get the asset track from the clip's asset
                let assetTracks = try await clip.asset.loadTracks(withMediaType: .video)
                guard let assetTrack = assetTracks.first else {
                    continue
                }

                try compositionTrack?.insertTimeRange(
                    clip.timeRangeInSource,
                    of: assetTrack,
                    at: clip.timeRangeInTimeline.start
                )
            }
        }

        // Add audio tracks
        for track in editorState.clipTracks.filter({ $0.type == .audio }) {
            let compositionTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            )

            for clip in track.clips {
                // Get the asset track from the clip's asset
                let assetTracks = try await clip.asset.loadTracks(withMediaType: .audio)
                guard let assetTrack = assetTracks.first else {
                    continue
                }

                try compositionTrack?.insertTimeRange(
                    clip.timeRangeInSource,
                    of: assetTrack,
                    at: clip.timeRangeInTimeline.start
                )
            }
        }

        return composition
    }

    /// Validates transitions before export
    private func validateTransitions() throws {
        for transition in editorState.transitions {
            guard transition.isEnabled else { continue }

            // Verify both clips exist
            let hasLeading = editorState.clipTracks.contains(where: { track in
                track.clips.contains(where: { $0.id == transition.leadingClipID })
            })
            let hasTrailing = editorState.clipTracks.contains(where: { track in
                track.clips.contains(where: { $0.id == transition.trailingClipID })
            })

            guard hasLeading, hasTrailing else {
                throw TransitionError.clipsNotFound(
                    leadingClipID: transition.leadingClipID,
                    trailingClipID: transition.trailingClipID
                )
            }
        }
    }
}
