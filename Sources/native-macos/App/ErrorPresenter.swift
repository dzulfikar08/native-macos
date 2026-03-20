import AppKit

/// Presents errors to users in a consistent manner
@MainActor
final class ErrorPresenter {
    /// Presents an error as a sheet on the given window
    func present(_ error: Error, from window: NSWindow) {
        let alert = NSAlert()
        alert.messageText = error.localizedDescription
        alert.informativeText = (error as? LocalizedError)?.recoverySuggestion ?? ""
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")

        alert.beginSheetModal(for: window) { _ in
            // Sheet dismissed
        }
    }

    /// Presents a critical error that blocks further action
    func presentCritical(_ error: Error, from window: NSWindow) {
        let alert = NSAlert()
        alert.messageText = "Critical Error"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Quit")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSApplication.shared.terminate(nil)
        }
    }

    /// Presents a non-modal error notification
    func presentNotification(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = error.localizedDescription
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")

        alert.runModal()
    }
}
