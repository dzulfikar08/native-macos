import AVFoundation
import AppKit

/// Manages recording state and coordinates recording operations
@MainActor
final class RecordingController: NSObject {
    private let screenRecorder = ScreenRecorder()
    private var currentRecordingURL: URL?
    var currentRecorder: (any Recorder)?
    var onFinishedRecording: ((URL) -> Void)?

    /// Starts a new recording session
    /// - Parameter displayID: Optional display ID to record specific display
    /// - Returns: URL where recording will be saved
    /// - Throws: RecordingError if recording cannot start
    func startRecording(displayID: CGDirectDisplayID? = nil) async throws -> URL {
        // Generate unique recording URL in ~/Movies/OpenScreenNative
        let url = try FileUtils.uniqueRecordingURL()
        currentRecordingURL = url

        // Start screen recording
        try await screenRecorder.startRecording(to: url, displayID: displayID)

        return url
    }

    /// Start recording with custom recorder
    /// - Parameters:
    ///   - recorder: Recorder instance (e.g., WebcamRecorder)
    ///   - config: Recorder-specific configuration
    /// - Returns: URL where recording will be saved
    /// - Throws: RecordingError if recording cannot start
    func startRecording<T: Recorder>(with recorder: T, config: T.Config) async throws -> URL {
        let url = try FileUtils.uniqueRecordingURL()
        currentRecordingURL = url
        try await recorder.startRecording(to: url, config: config)
        currentRecorder = recorder
        return url
    }

    /// Stops the current recording
    /// - Returns: URL of the recorded file
    /// - Throws: RecordingError if stop fails
    func stopRecording() async throws -> URL {
        guard currentRecordingURL != nil else {
            throw RecordingError.recordingInterrupted
        }

        let url: URL
        if let customRecorder = currentRecorder {
            // Use custom recorder (WebcamRecorder, etc.)
            url = try await customRecorder.stopRecording()
        } else {
            // Use default screen recorder
            url = try await screenRecorder.stopRecording()
        }

        // Verify file exists and has content
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? UInt64 ?? 0

        guard fileSize > 0 else {
            throw RecordingError.recordingInterrupted
        }

        print("📊 Recording size: \(fileSize) bytes")

        // Notify callback if set
        onFinishedRecording?(url)

        return url
    }

    /// Toggles recording on/off
    /// - Returns: URL if stopping, nil if starting
    /// - Throws: RecordingError if operation fails
    func toggleRecording() async throws -> URL? {
        if currentRecordingURL == nil {
            _ = try await startRecording(displayID: nil)
            return nil
        } else {
            return try await stopRecording()
        }
    }

    /// Check if currently recording from webcam
    var isWebcamRecording: Bool {
        currentRecorder is WebcamRecorder
    }
}
