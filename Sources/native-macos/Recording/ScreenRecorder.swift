import AVFoundation
import AppKit

/// Records screen activity using AVFoundation
@MainActor
final class ScreenRecorder: NSObject, ObservableObject {
    private var session: AVCaptureSession?
    private var screenInput: AVCaptureScreenInput?
    private var movieOutput: AVCaptureMovieFileOutput?
    private var isRecordingValue = false
    private var recordingURL: URL?

    /// Whether currently recording
    var isRecording: Bool { isRecordingValue }

    /// Starts recording to the specified URL
    /// - Parameters:
    ///   - url: Destination URL for the recorded video
    ///   - displayID: Optional display ID to record from. If nil, uses main display.
    /// - Throws: RecordingError if recording cannot start
    func startRecording(to url: URL, displayID: CGDirectDisplayID? = nil) async throws {
        guard !isRecordingValue else { return }

        // Check screen recording permission
        await checkScreenRecordingPermission()

        // Create session
        let session = AVCaptureSession()
        session.sessionPreset = .high

        // Determine which display to use
        let targetDisplayID: CGDirectDisplayID
        if let displayID = displayID {
            // Use provided display ID
            targetDisplayID = displayID
        } else {
            // Fall back to main display
            guard let display = NSScreen.main else {
                throw RecordingError.noDisplayAvailable
            }

            guard let mainDisplayID = display.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                throw RecordingError.noDisplayAvailable
            }

            targetDisplayID = mainDisplayID
        }

        // Create screen input
        guard let input = AVCaptureScreenInput(displayID: targetDisplayID) else {
            throw RecordingError.recordingInterrupted
        }

        input.capturesCursor = true
        input.capturesMouseClicks = true

        if session.canAddInput(input) {
            session.addInput(input)
        }

        // Create movie output
        let movieOutput = AVCaptureMovieFileOutput()
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }

        self.session = session
        self.screenInput = input
        self.movieOutput = movieOutput
        self.recordingURL = url

        // Start session
        session.startRunning()

        // Start recording
        movieOutput.startRecording(to: url, recordingDelegate: self)
        isRecordingValue = true

        print("📹 Recording started to: \(url.path)")
    }

    /// Stops the current recording
    /// - Returns: URL of the recorded file
    /// - Throws: RecordingError if stop fails
    func stopRecording() async throws -> URL {
        guard isRecordingValue, let movieOutput, let url = recordingURL else {
            throw RecordingError.recordingInterrupted
        }

        movieOutput.stopRecording()
        session?.stopRunning()
        isRecordingValue = false

        // Wait for file to be written
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Verify file was created
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw RecordingError.recordingInterrupted
        }

        print("✅ Recording saved to: \(url.path)")
        return url
    }

    /// Checks screen recording permission
    private func checkScreenRecordingPermission() async {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if !granted {
                    print("⚠️ Screen recording permission denied")
                }
                continuation.resume()
            }
        }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension ScreenRecorder: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput,
                               didFinishRecordingTo outputFileURL: URL,
                               from connections: [AVCaptureConnection],
                               error: Error?) {
        if let error {
            print("❌ Recording error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Recorder Protocol Conformance

extension ScreenRecorder: Recorder {
    /// Configuration for screen recording
    struct Config: Sendable {
        let displayID: CGDirectDisplayID?
    }

    func startRecording(to url: URL, config: Config) async throws {
        // Delegate to existing implementation
        try await startRecording(to: url, displayID: config.displayID)
    }
}
