import Foundation

/// Errors that can occur during screen recording
public enum RecordingError: LocalizedError, CustomStringConvertible, Sendable {
    case permissionDenied(type: PermissionType)
    case noDisplayAvailable
    case diskSpaceInsufficient(required: UInt64, available: UInt64)
    case recordingInterrupted
    case codecNotAvailable
    case noCameraSelected
    case cameraSetupFailed(String)
    case writerSetupFailed

    /// The type of permission that was denied
    public enum PermissionType: Sendable {
        case screenRecording
        case audio
    }

    private static let bytesPerGB: UInt64 = 1_000_000_000

    public var errorDescription: String? {
        switch self {
        case .permissionDenied(let type):
            switch type {
            case .screenRecording:
                return "Screen recording permission is required. Grant it in System Settings → Privacy & Security → Screen Recording"
            case .audio:
                return "Audio recording permission is required. Grant it in System Settings → Privacy & Security → Microphone"
            }
        case .noDisplayAvailable:
            return "No display is available for recording"
        case .diskSpaceInsufficient(let required, let available):
            let requiredGB = Double(required) / Double(Self.bytesPerGB)
            let availableGB = Double(available) / Double(Self.bytesPerGB)
            return "Not enough disk space. Required: \(String(format: "%.1f", requiredGB))GB, Available: \(String(format: "%.1f", availableGB))GB"
        case .recordingInterrupted:
            return "Recording was interrupted"
        case .codecNotAvailable:
            return "Required codec is not available on this system"
        case .noCameraSelected:
            return "No camera selected for recording"
        case .cameraSetupFailed(let camera):
            return "Failed to setup camera: \(camera)"
        case .writerSetupFailed:
            return "Failed to setup video writer"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "Grant the required permission in System Settings and restart the recording"
        case .noDisplayAvailable:
            return "Ensure at least one display is connected"
        case .diskSpaceInsufficient:
            return "Free up disk space or choose a different save location"
        case .recordingInterrupted:
            return "Restart the recording"
        case .codecNotAvailable:
            return "Update macOS to the latest version"
        case .noCameraSelected:
            return "Select at least one camera for recording"
        case .cameraSetupFailed:
            return "Ensure camera is connected and not in use by another application"
        case .writerSetupFailed:
            return "Check disk space and permissions"
        }
    }

    public var description: String {
        errorDescription ?? "Unknown recording error"
    }
}
