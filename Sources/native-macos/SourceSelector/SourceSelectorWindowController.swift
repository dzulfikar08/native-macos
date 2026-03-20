import AppKit

/// Window controller that presents the source selector as a modal sheet
/// with tabs for Screen, Window, Webcam, and Import video sources
@MainActor
final class SourceSelectorWindowController: NSWindowController {
    // MARK: - Properties

    /// Callback invoked when a source is selected
    private var onSourceSelected: ((SourceSelection) -> Void)?

    /// Callback invoked when the sheet is cancelled
    private var onCancelled: (() -> Void)?

    /// Tab view controller managing the four source tabs
    private var tabViewController: NSTabViewController?

    // MARK: - Initialization

    /// Convenience initializer creating the window and tab view
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Select Video Source"
        window.isReleasedWhenClosed = false

        self.init(window: window)
        setupTabView()
    }

    // MARK: - Setup

    /// Configures the tab view with four source selection tabs
    private func setupTabView() {
        let tabVC = NSTabViewController()

        // Create screen source tab
        let screenVC = ScreenSourceViewController()
        let screenTab = NSTabViewItem(viewController: screenVC)
        screenTab.label = "Screen"
        screenTab.image = NSImage(systemSymbolName: "display", accessibilityDescription: "Screen")

        // Create window source tab (placeholder for Phase 4)
        let windowVC = WindowSourceViewController()
        let windowTab = NSTabViewItem(viewController: windowVC)
        windowTab.label = "Window"
        windowTab.image = NSImage(systemSymbolName: "window.on.square", accessibilityDescription: "Window")

        // Create webcam source tab (placeholder for Phase 3)
        let webcamVC = WebcamSourceViewController()
        let webcamTab = NSTabViewItem(viewController: webcamVC)
        webcamTab.label = "Webcam"
        webcamTab.image = NSImage(systemSymbolName: "video.circle", accessibilityDescription: "Webcam")

        // Create video import tab (placeholder for Phase 2)
        let importVC = VideoImportViewController()
        let importTab = NSTabViewItem(viewController: importVC)
        importTab.label = "Import"
        importTab.image = NSImage(systemSymbolName: "square.and.arrow.down", accessibilityDescription: "Import")

        // Handle video import via callback
        importVC.onVideoSelected = { [weak self] url in
            guard let self = self else { return }
            self.onSourceSelected?(.videoFile(url: url))
        }

        // Add tabs to tab view controller
        tabVC.addTabViewItem(screenTab)
        tabVC.addTabViewItem(windowTab)
        tabVC.addTabViewItem(webcamTab)
        tabVC.addTabViewItem(importTab)

        self.tabViewController = tabVC
        window?.contentViewController = tabVC

        // Handle screen selection via callback
        screenVC.onSelectionChanged = { [weak self] displayItem in
            guard let self = self, let item = displayItem else { return }
            self.onSourceSelected?(.screen(displayID: item.id, displayName: item.name))
        }
    }

    // MARK: - Presentation

    /// Presents the source selector as a modal sheet on the specified window
    /// - Parameters:
    ///   - parentWindow: The window to present the sheet on
    ///   - onSelected: Callback invoked when a source is selected
    ///   - onCancelled: Callback invoked when the sheet is cancelled
    func presentAsSheet(
        on parentWindow: NSWindow,
        onSelected: @escaping @Sendable (SourceSelection) -> Void,
        onCancelled: @escaping @Sendable () -> Void
    ) {
        self.onSourceSelected = onSelected
        self.onCancelled = onCancelled

        guard let sheetWindow = self.window else {
            onCancelled()
            return
        }

        parentWindow.beginSheet(sheetWindow) { [weak self] response in
            guard let self = self else { return }
            if response == .OK {
                // Selection handled via onSourceSelected callback
            } else {
                self.onCancelled?()
            }
            // Clear callbacks to prevent memory leaks
            self.onSourceSelected = nil
            self.onCancelled = nil
        }
    }
}
