import AppKit

/// Main application delegate for OpenScreen
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowManager: WindowManager?
    private let resourceCoordinator = ResourceCoordinator()
    private let errorPresenter = ErrorPresenter()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure app activation policy
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // Start resource monitoring
        resourceCoordinator.startMonitoring()

        // Initialize window manager
        windowManager = WindowManager(
            resourceCoordinator: resourceCoordinator,
            errorPresenter: errorPresenter
        )
        windowManager?.transition(to: .sourceSelector)

        // Setup document types for video file handling
        setupDocumentTypes()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Check for unsaved changes
        if let windowManager = windowManager, windowManager.hasUnsavedChanges {
            let alert = NSAlert()
            alert.messageText = "Unsaved Changes"
            alert.informativeText = "You have unsaved changes. Do you want to save before quitting?"
            alert.addButton(withTitle: "Save")
            alert.addButton(withTitle: "Don't Save")
            alert.addButton(withTitle: "Cancel")

            let response = alert.runModal()
            switch response {
            case .alertFirstButtonReturn:  // Save
                Task {
                    do {
                        try await windowManager.saveAllChanges()
                        NSApp.reply(toApplicationShouldTerminate: true)
                    } catch {
                        errorPresenter.presentCritical(error, from: NSApp.keyWindow!)
                        NSApp.reply(toApplicationShouldTerminate: false)
                    }
                }
                return .terminateLater
            case .alertSecondButtonReturn:  // Don't Save
                return .terminateNow
            default:  // Cancel
                return .terminateCancel
            }
        }
        return .terminateNow
    }

    func applicationWillBecomeActive(_ notification: Notification) {
        // Resume paused operations
        windowManager?.resumeBackgroundWork()
    }

    func applicationWillResignActive(_ notification: Notification) {
        // Pause resource-intensive operations
        windowManager?.pauseBackgroundWork()
    }

    func applicationWillHide(_ notification: Notification) {
        // Optionally hide HUD
        windowManager?.hideHUD()
    }

    // MARK: - Document Types

    private func setupDocumentTypes() {
        // Initialize document controller
        _ = NSDocumentController.shared

        // Register document type for video files
        NSApp.registerDocumentType(
            typeName: "Video File",
            extensions: ["mp4", "mov", "mkv", "avi", "m4v"],
            mimeTypes: ["video/mp4", "video/quicktime", "video/x-matroska"],
            icon: nil
        )
    }

    // MARK: - File Opening

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        let url = URL(fileURLWithPath: filename)
        return handleVideoImport(url: url)
    }

    func application(_ application: NSApplication, openFiles filenames: [String]) {
        // Handle multiple files (import first one, show warning for others)
        if let firstFile = filenames.first {
            let url = URL(fileURLWithPath: firstFile)
            _ = handleVideoImport(url: url)
        }

        if filenames.count > 1 {
            print("⚠️ Only the first file was imported. Multiple file import not yet supported.")
        }
    }

    private func handleVideoImport(url: URL) -> Bool {
        // Validate it's a video file
        guard VideoValidator.isSupportedFormat(url: url) else {
            showUnsupportedFormatError(url)
            return false
        }

        // Trigger import flow
        // TODO: Task 6 will implement importVideo method
        Task { @MainActor in
            guard self.windowManager != nil else { return }
            // await windowManager.importVideo(from: url)
            print("ℹ️ Video import to be implemented in Task 6: \(url.lastPathComponent)")
        }

        return true
    }

    private func showUnsupportedFormatError(_ url: URL) {
        let alert = NSAlert()
        alert.messageText = "Unsupported Format"
        alert.informativeText = "The file \(url.lastPathComponent) is not a supported video format."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - NSApplication Extensions

extension NSApplication {
    /// Registers document types programmatically for video file handling
    func registerDocumentType(
        typeName: String,
        extensions: [String],
        mimeTypes: [String],
        icon: NSImage?
    ) {
        // Document types are primarily registered via Info.plist
        // This is a placeholder for any runtime registration needs
        // The actual file type handling is done through:
        // - NSDocumentController for recent files
        // - application(_:openFile:) for file opening
        // - VideoValidator for format validation
        print("Registered document type: \(typeName) with extensions: \(extensions.joined(separator: ", "))")
    }
}
