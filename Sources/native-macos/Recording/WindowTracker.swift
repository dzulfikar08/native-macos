import Foundation
import CoreGraphics
import Combine
import AppKit

/// Tracks window state changes for pause/resume functionality
@MainActor
final class WindowTracker: ObservableObject {
    /// Represents the visibility state of a window being tracked
    /// Note: The `hidden` case is defined but not currently returned by determineWindowState().
    /// Hidden windows are treated as visible for recording purposes since they can still be captured.
    enum WindowState {
        case visible
        case hidden
        case minimized
        case closed
        case onOtherSpace
    }

    @Published var windowState: [CGWindowID: WindowState] = [:]

    private var trackingTimer: Timer?
    var onWindowStateChanged: ((CGWindowID, WindowState) -> Void)?

    /// Starts tracking window states
    func startTracking(windowIDs: [CGWindowID]) {
        // Initialize all windows as visible
        for id in windowIDs {
            windowState[id] = .visible
        }

        // Check window states every 500ms
        trackingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkWindowStates()
            }
        }
    }

    /// Stops tracking window states
    func stopTracking() {
        trackingTimer?.invalidate()
        trackingTimer = nil
    }

    /// Checks if a window is available for recording
    func isWindowAvailable(_ windowID: CGWindowID) -> Bool {
        guard let state = windowState[windowID] else {
            return false
        }
        return state == .visible
    }

    // MARK: - Private

    /// Returns the workspace number of the current space
    private func CGWorkspaceNumberOfCurrentSpace() -> Int {
        // Use NSWorkspace to get current space info
        // For simplicity, we'll assume workspace 0 is current
        // In production, this would use private APIs or workspace notifications
        return 0
    }

    private func checkWindowStates() {
        guard let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
            return
        }

        var currentWindows: Set<CGWindowID> = []
        var windowLayers: [CGWindowID: Int] = [:]
        var windowWorkspaceNumbers: [CGWindowID: Int] = [:]

        for windowInfo in windowList {
            guard let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID else {
                continue
            }

            currentWindows.insert(windowID)

            if let layer = windowInfo[kCGWindowLayer as String] as? Int {
                windowLayers[windowID] = layer
            }

            // kCGWorkspaceNumber is not publicly available, use string key
            if let workspaceNumber = windowInfo["kCGWorkspaceNumber"] as? Int {
                windowWorkspaceNumbers[windowID] = workspaceNumber
            }
        }

        let currentWorkspaceNumber = CGWorkspaceNumberOfCurrentSpace()

        for (windowID, oldState) in windowState {
            let newState = determineWindowState(
                windowID: windowID,
                currentWindows: currentWindows,
                windowLayers: windowLayers,
                windowWorkspaceNumbers: windowWorkspaceNumbers,
                currentWorkspaceNumber: currentWorkspaceNumber
            )

            if newState != oldState {
                windowState[windowID] = newState
                onWindowStateChanged?(windowID, newState)
            }
        }
    }

    private func determineWindowState(
        windowID: CGWindowID,
        currentWindows: Set<CGWindowID>,
        windowLayers: [CGWindowID: Int],
        windowWorkspaceNumbers: [CGWindowID: Int],
        currentWorkspaceNumber: Int
    ) -> WindowState {
        // Window closed or doesn't exist
        if !currentWindows.contains(windowID) {
            return .closed
        }

        // Window minimized (layer == 0 indicates minimized)
        if let layer = windowLayers[windowID], layer == 0 {
            return .minimized
        }

        // Window on different space
        if let workspaceNumber = windowWorkspaceNumbers[windowID],
           workspaceNumber != currentWorkspaceNumber {
            return .onOtherSpace
        }

        // Window is visible
        return .visible
    }
}
