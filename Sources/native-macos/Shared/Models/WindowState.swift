import Foundation

/// Represents the current state of the application window management
enum WindowState: Equatable, Sendable {
    case idle
    case sourceSelector
    case recording
    case editing
    case exporting

    var canTransitionTo: [WindowState] {
        switch self {
        case .idle:
            return [.sourceSelector]
        case .sourceSelector:
            return [.idle, .recording, .editing]
        case .recording:
            return [.idle, .editing]
        case .editing:
            return [.idle, .exporting]
        case .exporting:
            return [.editing]
        }
    }
}
