import AVFoundation
import Foundation

/// Handles video export functionality with progress reporting via notifications
@MainActor
final class VideoExporter: NSObject, ObservableObject {

    // MARK: - State Management

    private var exportSession: AVAssetExportSession?
    private var isExporting = false
    private var progressTimer: Timer?

    // MARK: - Export Configuration

    /// Export preset to use for the export
    private let exportPreset: String

    /// Output file URL for the exported video
    private let outputURL: URL

    /// Asset to export
    private let asset: AVAsset

    /// Video composition to apply during export
    private var videoComposition: AVVideoComposition?

    /// Quality settings for export
    private let quality: ExportQualitySettings

    /// Progress interval in seconds for progress updates
    private let progressInterval: TimeInterval = 0.1

    // MARK: - Initialization

    /// Initialize a new VideoExporter
    /// - Parameters:
    ///   - asset: The AVAsset to export
    ///   - outputURL: URL where the exported video will be saved
    ///   - quality: Export quality settings (defaults to .good)
    init(
        asset: AVAsset,
        outputURL: URL,
        quality: ExportQualitySettings = .good
    ) {
        self.asset = asset
        self.outputURL = outputURL
        self.quality = quality
        self.exportPreset = Self.mapQualityToPreset(quality)
        super.init()

        // Cleanup any existing export session
        cleanupExportSession()
    }

    deinit {
        // cleanupExportSession() will be called automatically when the object is deallocated
        // since it's already marked @MainActor
    }

    // MARK: - Public Interface

    /// Sets the video composition for export
    /// - Parameter composition: The video composition to apply
    func setVideoComposition(_ composition: AVVideoComposition) {
        self.videoComposition = composition
    }

    /// Start the export process
    func startExport() async throws {
        guard !isExporting else {
            throw ExportError.alreadyExporting
        }

        isExporting = true

        // Begin export notification
        let beginInfo: [String: Any] = [
            "outputURL": outputURL,
            "exportPreset": exportPreset,
            "startTime": Date()
        ]
        NotificationCenter.default.post(
            name: .didBeginExport,
            object: self,
            userInfo: beginInfo
        )

        do {
            // Create export session
            exportSession = try createExportSession()

            // Start progress monitoring
            startProgressMonitoring()

            // Start export
            _ = await exportSession!.export()

            // Export completed successfully
            let completeInfo: [String: Any] = [
                "outputURL": outputURL,
                "duration": asset.duration.seconds,
                "fileSize": try getFileSize(at: outputURL)
            ]
            NotificationCenter.default.post(
                name: .didCompleteExport,
                object: self,
                userInfo: completeInfo
            )

        } catch {
            // Export failed
            let failInfo: [String: Any] = [
                "outputURL": outputURL,
                "error": error
            ]
            NotificationCenter.default.post(
                name: .didFailExport,
                object: self,
                userInfo: failInfo
            )
            throw error
        }

        isExporting = false
        cleanupExportSession()
    }

    /// Cancel the current export process
    func cancelExport() {
        guard isExporting else { return }

        exportSession?.cancelExport()
        isExporting = false

        // Cancel progress monitoring
        progressTimer?.invalidate()
        progressTimer = nil

        // Cancel export notification
        let cancelInfo: [String: Any] = [
            "outputURL": outputURL,
            "progress": exportSession?.progress ?? 0.0
        ]
        NotificationCenter.default.post(
            name: .didCancelExport,
            object: self,
            userInfo: cancelInfo
        )

        cleanupExportSession()
    }

    /// Check if an export is currently in progress
    var isCurrentlyExporting: Bool {
        return isExporting
    }

    /// Get current export progress (0.0 to 1.0)
    var currentProgress: Float {
        return exportSession?.progress ?? 0.0
    }

    // MARK: - Private Methods

    /// Maps quality settings to AVAssetExportPreset
    /// - Parameter quality: Export quality settings
    /// - Returns: Appropriate AVAssetExportPreset
    /// - Note: Anti-aliasing is controlled by quality.antiAliasing in the renderer.
    ///   Custom bitrate (quality.bitrate) is not currently supported by AVAssetExportSession.
    ///   Custom renderSize (quality.renderSize) is handled by AVVideoComposition, not the export preset.
    private static func mapQualityToPreset(_ quality: ExportQualitySettings) -> String {
        switch quality.preset {
        case .draft:
            return AVAssetExportPreset640x480
        case .good:
            return AVAssetExportPreset1920x1080
        case .best:
            return AVAssetExportPreset3840x2160
        case .custom:
            // Use highest quality for custom, anti-aliasing will be applied in renderer
            return AVAssetExportPresetHighestQuality
        }
    }

    private func createExportSession() throws -> AVAssetExportSession {
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: exportPreset
        ) else {
            throw ExportError.invalidExportPreset
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov

        // Apply video composition if set
        if let composition = videoComposition {
            exportSession.videoComposition = composition
        }

        return exportSession
    }

    private func startProgressMonitoring() {
        progressTimer = Timer.scheduledTimer(
            withTimeInterval: progressInterval,
            repeats: true
        ) { [weak self] _ in
            self?.reportProgress()
        }
    }

    private func reportProgress() {
        guard let progress = exportSession?.progress else {
            return
        }

        let progressInfo: [String: Any] = [
            "progress": progress,
            "currentTime": 0.0,
            "duration": asset.duration.seconds,
            "outputURL": outputURL
        ]

        NotificationCenter.default.post(
            name: .exportProgress,
            object: self,
            userInfo: progressInfo
        )
    }

    private func getFileSize(at url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.size] as? Int64 ?? 0
    }

    private func cleanupExportSession() {
        progressTimer?.invalidate()
        progressTimer = nil
        exportSession = nil
    }
}

// MARK: - Export Error Type

enum ExportError: Error, LocalizedError {
    case alreadyExporting
    case invalidExportPreset
    case outputFileExists
    case noOutputURL
    case noVideoTracks
    case emptyComposition

    var errorDescription: String? {
        switch self {
        case .alreadyExporting:
            return "Export is already in progress"
        case .invalidExportPreset:
            return "Invalid export preset"
        case .outputFileExists:
            return "Output file already exists"
        case .noOutputURL:
            return "No output URL provided"
        case .noVideoTracks:
            return "No video tracks found in timeline"
        case .emptyComposition:
            return "Video composition has no instructions"
        }
    }
}