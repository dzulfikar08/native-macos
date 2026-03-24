import AppKit

/// Manages the screen source selection interface, enumerating connected displays
/// and presenting them as selectable options with thumbnails
@MainActor
final class ScreenSourceViewController: NSViewController {
    // MARK: - Properties

    /// Array of discovered display items
    private(set) var displays: [DisplayItem] = []

    /// Currently selected display item
    private(set) var selectedItem: DisplayItem?

    /// Callback invoked when selection changes
    var onSelectionChanged: ((DisplayItem?) -> Void)?

    // MARK: - Display Enumeration

    /// Enumerates all online displays and returns them as display items
    /// - Returns: Array of DisplayItem objects representing connected displays
    func enumerateDisplays() -> [DisplayItem] {
        print("🔍 Starting display enumeration...")
        var result: [DisplayItem] = []
        let maxDisplays: UInt32 = 32
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
        var displayCount: UInt32 = 0

        let error = CGGetOnlineDisplayList(maxDisplays, &displayIDs, &displayCount)
        print("🔍 CGGetOnlineDisplayList result: \(error), displayCount: \(displayCount)")

        guard error == .success else {
            print("⚠️ Failed to enumerate displays: \(error)")
            return result
        }

        guard displayCount > 0 else {
            print("⚠️ No displays detected")
            return result
        }

        for i in 0..<Int(displayCount) {
            let displayID = displayIDs[i]
            let name = getDisplayName(for: displayID)
            let width = CGDisplayPixelsWide(displayID)
            let height = CGDisplayPixelsHigh(displayID)

            print("📺 Display \(i): ID=\(displayID), Name=\(name), Size=\(width)x\(height)")

            let item = DisplayItem(
                id: displayID,
                name: name,
                width: width,
                height: height,
                thumbnail: generateThumbnail(for: displayID)
            )
            result.append(item)
        }

        displays = result
        print("✅ Found \(result.count) display(s)")
        return result
    }

    // MARK: - Display Information

    /// Resolves the display name from NSScreen for a given display ID
    /// - Parameter displayID: The display ID to resolve
    /// - Returns: Human-readable display name
    private func getDisplayName(for displayID: CGDirectDisplayID) -> String {
        if let screen = NSScreen.screens.first(where: { screen in
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                return false
            }
            return id == displayID
        }) {
            return screen.localizedName
        }
        return "Display \(displayID)"
    }

    /// Generates a thumbnail image for the specified display
    /// - Parameter displayID: The display ID to capture
    /// - Returns: NSImage thumbnail (320x200) or nil if capture fails
    private func generateThumbnail(for displayID: CGDirectDisplayID) -> NSImage? {
        guard let image = CGDisplayCreateImage(displayID) else {
            return nil
        }
        let size = NSSize(width: 320, height: 200)
        return NSImage(cgImage: image, size: size)
    }

    // MARK: - Selection

    /// Selects a display item and invokes the selection callback
    /// - Parameter item: The DisplayItem to select, or nil to clear selection
    func selectDisplay(_ item: DisplayItem?) {
        selectedItem = item
        onSelectionChanged?(item)
    }

    // MARK: - NSViewController Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Check permissions first
        checkPermissions()
    }

    // MARK: - Permissions

    private func checkPermissions() {
        let status = CGPreflightScreenCaptureAccess()
        print("🔍 Screen capture permission status: \(status)")

        if !status {
            print("❌ Permission denied, showing alert")
            showPermissionDeniedAlert()
        } else {
            print("✅ Permission granted, enumerating displays")
            // Enumerate displays when permission is granted
            let displays = enumerateDisplays()
            print("📺 Found \(displays.count) display(s)")
        }
    }

    private func showPermissionDeniedAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Access Required"
        alert.informativeText = "OpenScreen needs screen recording permission to enumerate displays. After granting permission, click Retry to continue."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Retry")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            // Open System Settings
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        } else if response == .alertSecondButtonReturn {
            // Retry - check permissions again
            checkPermissions()
        }
    }
}
