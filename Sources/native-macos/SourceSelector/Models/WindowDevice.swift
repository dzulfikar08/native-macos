import Foundation
import CoreGraphics
import AppKit

/// Represents a window that can be recorded
struct WindowDevice: Identifiable, Sendable {
    let id: CGWindowID
    let name: String
    let ownerName: String
    var bounds: CGRect
    var thumbnail: NSImage?

    /// Enumerates all available windows for recording
    static func enumerateWindows() -> [WindowDevice] {
        // Include windows from all spaces, not just current space
        guard let windowList = CGWindowListCopyWindowInfo(.optionOnScreenAboveWindow, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        var devices: [WindowDevice] = []

        // Get current app name to filter out OpenScreen's own windows
        let currentAppName = Bundle.main.infoDictionary?["CFBundleName"] as? String
            ?? ProcessInfo.processInfo.processName

        for windowInfo in windowList {
            guard let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                  let name = windowInfo[kCGWindowName as String] as? String,
                  let ownerName = windowInfo[kCGWindowOwnerName as String] as? String,
                  let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any],
                  let layer = windowInfo[kCGWindowLayer as String] as? Int else {
                continue
            }

            // Filter out menu bar, dock, and other system windows
            if layer == 0 {
                continue
            }

            // Filter out windows owned by OpenScreen itself
            if ownerName == currentAppName {
                continue
            }

            // Filter out windows without names
            if name.isEmpty || ownerName.isEmpty {
                continue
            }

            // Parse bounds
            guard let x = boundsDict["X"] as? CGFloat,
                  let y = boundsDict["Y"] as? CGFloat,
                  let width = boundsDict["Width"] as? CGFloat,
                  let height = boundsDict["Height"] as? CGFloat else {
                continue
            }

            let bounds = CGRect(x: x, y: y, width: width, height: height)

            // Filter out small windows
            if width < 100 || height < 100 {
                continue
            }

            let device = WindowDevice(
                id: windowID,
                name: name,
                ownerName: ownerName,
                bounds: bounds
            )

            devices.append(device)
        }

        return devices
    }

    /// Updates bounds for all devices in place
    static func updateWindowBounds(_ devices: inout [WindowDevice]) {
        guard let windowList = CGWindowListCopyWindowInfo(.optionOnScreenAboveWindow, kCGNullWindowID) as? [[String: Any]] else {
            return
        }

        var boundsMap: [CGWindowID: CGRect] = [:]

        for windowInfo in windowList {
            guard let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                  let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any] else {
                continue
            }

            guard let x = boundsDict["X"] as? CGFloat,
                  let y = boundsDict["Y"] as? CGFloat,
                  let width = boundsDict["Width"] as? CGFloat,
                  let height = boundsDict["Height"] as? CGFloat else {
                continue
            }

            boundsMap[windowID] = CGRect(x: x, y: y, width: width, height: height)
        }

        for index in devices.indices {
            if let newBounds = boundsMap[devices[index].id] {
                devices[index].bounds = newBounds
            }
        }
    }

    /// Creates a thumbnail image for this window
    func createThumbnail() -> NSImage? {
        guard let image = CGWindowListCreateImage(.null, .optionIncludingWindow, id, .boundsIgnoreFraming) else {
            return nil
        }

        let thumbnailSize = NSSize(width: 160, height: 120)
        return NSImage(cgImage: image, size: thumbnailSize)
    }
}
