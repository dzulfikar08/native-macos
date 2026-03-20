import AppKit
import AVFoundation

/// Manages application windows and state transitions
@MainActor
final class WindowManager {
    private var hudWindowController: HUDWindowController?
    private var sourceSelectorWindowController: NSWindowController?
    private var editorWindowController: EditorWindowController?
    private var miniRecordingView: MiniRecordingView?
    private var currentState: WindowState = .idle
    private var recordingToEdit: URL?
    private let resourceCoordinator: ResourceCoordinator
    private let errorPresenter: ErrorPresenter

    init(resourceCoordinator: ResourceCoordinator, errorPresenter: ErrorPresenter) {
        self.resourceCoordinator = resourceCoordinator
        self.errorPresenter = errorPresenter
    }

    /// Transitions to a new window state
    func transition(to newState: WindowState) {
        guard isValidTransition(from: currentState, to: newState) else {
            print("⚠️ Invalid transition from \(currentState) to \(newState)")
            return
        }

        cleanupWindows(for: currentState)
        setupWindows(for: newState)
        currentState = newState
    }

    /// Checks if a state transition is valid
    private func isValidTransition(from: WindowState, to: WindowState) -> Bool {
        return from.canTransitionTo.contains(to)
    }

    /// Cleans up windows for a given state
    private func cleanupWindows(for state: WindowState) {
        switch state {
        case .idle:
            break
        case .sourceSelector:
            sourceSelectorWindowController?.close()
            sourceSelectorWindowController = nil
        case .recording:
            hudWindowController?.close()
            hudWindowController = nil
        case .editing:
            editorWindowController?.close()
            editorWindowController = nil
        case .exporting:
            break
        }
    }

    /// Sets up windows for a given state
    private func setupWindows(for state: WindowState) {
        switch state {
        case .idle:
            break
        case .sourceSelector:
            showSourceSelector()
        case .recording:
            showHUD()
        case .editing:
            // Editor window is shown when recording finishes
            break
        case .exporting:
            break
        }
    }

    /// Shows the source selector window
    func showSourceSelector() {
        let sourceSelector = SourceSelectorWindowController()

        // Get parent window (or create a temporary one)
        let parentWindow = NSApp.windows.first { $0.canBecomeMain }

        guard let window = parentWindow else {
            print("⚠️ No parent window available for sheet")
            return
        }

        sourceSelector.presentAsSheet(on: window) { [weak self] selection in
            guard let self = self else { return }

            switch selection {
            case .screen(let displayID, let displayName):
                print("✅ Selected display: \(displayName) (ID: \(displayID))")

                // Show HUD and start recording with selected display
                Task { @MainActor in
                    // Setup first, then transition after successful setup
                    self.showHUD()

                    guard let recordingController = self.getRecordingController() else {
                        print("⚠️ RecordingController not available")
                        // Rollback to idle state on setup failure
                        self.transition(to: .idle)
                        return
                    }

                    do {
                        _ = try await recordingController.startRecording(displayID: displayID)
                        // Only transition to recording after successful setup
                        self.transition(to: .recording)
                    } catch {
                        // Rollback to idle state on recording failure
                        self.transition(to: .idle)
                        self.errorPresenter.presentCritical(error, from: window)
                    }
                }

            case .webcam(let cameras, let settings):
                print("✅ Selected \(cameras.count) camera(s)")

                Task { @MainActor in
                    let config = WebcamRecorder.WebcamRecordingConfig(
                        cameras: cameras,
                        compositingMode: settings.compositingMode,
                        videoSettings: .init(
                            resolution: settings.qualityPreset.resolution,
                            frameRate: settings.qualityPreset.framerate,
                            bitrate: settings.qualityPreset.bitrate
                        ),
                        audioSettings: settings.audioSettings,
                        codec: settings.codec
                    )

                    let recorder = WebcamRecorder()
                    do {
                        self.showHUD()

                        guard let recordingController = self.getRecordingController() else {
                            print("⚠️ RecordingController not available")
                            self.transition(to: .idle)
                            return
                        }

                        let url = try await recordingController.startRecording(with: recorder, config: config)
                        await self.handleRecordingStarted(url)
                    } catch {
                        await self.handleRecordingError(error)
                        self.errorPresenter.presentCritical(error, from: window)
                    }
                }

            case .videoFile(let url):
                print("✅ Selected video file: \(url.lastPathComponent)")

                // Validate and load video
                Task { @MainActor in
                    await self.importVideo(from: url)
                }
            }
        } onCancelled: { [weak self] in
            print("ℹ️ Source selector cancelled")
            Task { @MainActor in
                self?.transition(to: .idle)
            }
        }
    }

    /// Shows the HUD window
    func showHUD() {
        let screen = NSScreen.main
        let width: CGFloat = 500
        let height: CGFloat = 80
        let work = screen?.visibleFrame ?? NSRect(x: 100, y: 100, width: width, height: height)
        let x = work.midX - width / 2
        let y = work.minY + 40
        let frame = NSRect(x: x, y: y, width: width, height: height)

        let controller = HUDWindowController(hudFrame: frame)
        controller.recordingController.onFinishedRecording = { [weak self] url in
            DispatchQueue.main.async {
                self?.recordingToEdit = url
                let editor = EditorWindowController(recordingURL: url)
                editor.showWindow(nil)
                self?.editorWindowController = editor
                self?.currentState = .editing
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
        controller.showWindow(nil)
        hudWindowController = controller
    }

    /// Hides the HUD window
    func hideHUD() {
        hudWindowController?.window?.orderOut(nil)
    }

    /// Checks if there are unsaved changes
    var hasUnsavedChanges: Bool {
        // Phase 2.1: No unsaved changes yet
        return false
    }

    /// Saves all pending changes
    func saveAllChanges() async throws {
        // Phase 2.1: No project saving yet
        print("ℹ️ Project saving implemented in Phase 2.2")
    }

    /// Exposes recording controller from HUD
    func getRecordingController() -> RecordingController? {
        return hudWindowController?.recordingController
    }

    /// Resumes background work
    func resumeBackgroundWork() {
        print("ℹ️ Resuming background work")
        // Background work management will be enhanced in Phase 2
    }

    /// Pauses background work
    func pauseBackgroundWork() {
        print("ℹ️ Pausing background work")
        // Background work management will be enhanced in Phase 2
    }

    /// Imports a video file and loads it into the editor
    /// - Parameter url: URL of video file to import
    func importVideo(from url: URL) async {
        // Validate video
        let result = VideoValidator.validate(url: url)

        switch result {
        case .success(let metadata):
            // Show metadata and confirm
            await showImportConfirmation(url: url, metadata: metadata)

        case .failure(let error):
            // Show error to user
            let window = NSApp.windows.first { $0.canBecomeMain }
            if let window = window {
                errorPresenter.present(error, from: window)
            }
        }
    }

    private func showImportConfirmation(url: URL, metadata: VideoMetadata) async {
        // Show confirmation dialog with metadata
        let alert = NSAlert()
        alert.messageText = "Import Video?"
        alert.informativeText = """
        Duration: \(metadata.durationString)
        Resolution: \(metadata.resolutionString)
        File Size: \(metadata.fileSizeString)

        Would you like to import this video into the editor?
        """

        if metadata.hasWarnings {
            alert.informativeText += "\n\nWarnings:\n" + metadata.warnings.joined(separator: "\n")
        }

        alert.alertStyle = .informational
        alert.addButton(withTitle: "Import")
        alert.addButton(withTitle: "Cancel")

        let window = NSApp.windows.first { $0.canBecomeMain }
        guard let window = window else { return }

        let response = await alert.beginSheetModal(for: window)

        if response == .alertFirstButtonReturn {
            // User confirmed import
            loadVideoIntoEditor(url: url)
        }
    }

    private func loadVideoIntoEditor(url: URL) {
        // Transition to editing state
        transition(to: .editing)

        // Create editor window with video URL
        let editor = EditorWindowController(recordingURL: url)
        editor.showWindow(nil)

        // Add to recent files
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
    }

    // MARK: - Webcam Recording Helpers

    private func handleRecordingStarted(_ url: URL) async {
        print("✅ Recording started: \(url.lastPathComponent)")

        // Show mini-view for webcam recordings
        if let recordingController = getRecordingController(),
           recordingController.isWebcamRecording {
            await showMiniRecordingView()
        }

        transition(to: .recording)
    }

    @MainActor
    private func showMiniRecordingView() async {
        guard let recordingController = getRecordingController(),
              let recorder = recordingController.currentRecorder as? WebcamRecorder else {
            return
        }

        let miniView = MiniRecordingView()
        miniView.onStop = { [weak self] in
            Task { @MainActor in
                guard let recordingController = self?.getRecordingController() else { return }
                _ = try? await recordingController.stopRecording()
            }
        }

        miniView.updatePreview(session: recorder.captureSession ?? AVCaptureSession())
        miniView.makeKeyAndOrderFront(nil)

        self.miniRecordingView = miniView
    }

    private func handleRecordingStopped(_ url: URL) async {
        print("✅ Recording stopped: \(url.lastPathComponent)")

        // Hide mini-view
        miniRecordingView?.close()
        miniRecordingView = nil

        hideHUD()
    }

    private func handleRecordingError(_ error: Error) async {
        print("❌ Recording failed: \(error)")

        // Hide mini-view
        miniRecordingView?.close()
        miniRecordingView = nil

        transition(to: .idle)
        hideHUD()
    }
}
