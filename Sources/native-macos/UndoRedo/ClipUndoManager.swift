import Foundation

/// Errors that can occur during undo/redo operations
enum UndoError: LocalizedError {
    case nothingToUndo
    case nothingToRedo
    case invalidState

    var errorDescription: String? {
        switch self {
        case .nothingToUndo:
            return "No operations to undo"
        case .nothingToRedo:
            return "No operations to redo"
        case .invalidState:
            return "Invalid undo/redo state"
        }
    }
}

/// Manages undo/redo operations for clip editing
/// Note: Not Sendable. All access must remain on @MainActor.
@MainActor
final class ClipUndoManager {
    // MARK: - Dependencies

    /// Weak reference to the editor state
    weak var editorState: EditorState?

    // MARK: - Stacks

    /// Stack of operations that can be undone
    private(set) var undoStack: [ClipOperation] = []

    /// Stack of operations that can be redone
    private(set) var redoStack: [ClipOperation] = []

    // MARK: - Configuration

    /// Strategy for coalescing operations
    var coalescingStrategy: CoalescingStrategy = .smart

    /// Limit for history size
    var historyLimit: HistoryLimit = .hybrid(maxOps: 100, timeWindow: 600)

    // MARK: - Query Properties

    /// Whether undo is available
    var canUndo: Bool { !undoStack.isEmpty }

    /// Whether redo is available
    var canRedo: Bool { !redoStack.isEmpty }

    /// Description of the next undo operation
    var undoDescription: String? { undoStack.last?.description }

    /// Description of the next redo operation
    var redoDescription: String? { redoStack.last?.description }

    // MARK: - Initialization

    /// Initialize with an editor state
    /// - Parameter editorState: The editor state to manage operations for
    init(editorState: EditorState) {
        self.editorState = editorState
    }

    // MARK: - Operations

    /// Execute an operation and add it to the undo stack
    /// - Parameter operation: The operation to execute
    /// - Throws: If the operation fails to execute
    func executeOperation(_ operation: ClipOperation) throws {
        // Execute the operation
        try operation.execute()

        // Add to undo stack
        undoStack.append(operation)

        // Clear redo stack (new operation invalidates redo history)
        redoStack.removeAll()

        // Enforce history limits
        enforceHistoryLimit()

        // Post notification
        postUndoChangeNotification()
    }

    /// Undo the last operation
    /// - Throws: If there's nothing to undo or the undo fails
    func undo() throws {
        guard !undoStack.isEmpty else {
            throw UndoError.nothingToUndo
        }

        let operation = undoStack.removeLast()

        do {
            try operation.undo()
            redoStack.append(operation)
            postUndoChangeNotification()
        } catch {
            // If undo fails, put operation back on undo stack
            undoStack.append(operation)
            throw error
        }
    }

    /// Redo the last undone operation
    /// - Throws: If there's nothing to redo or the redo fails
    func redo() throws {
        guard !redoStack.isEmpty else {
            throw UndoError.nothingToRedo
        }

        let operation = redoStack.removeLast()

        do {
            try operation.redo()
            undoStack.append(operation)
            postUndoChangeNotification()
        } catch {
            // If redo fails, put operation back on redo stack
            redoStack.append(operation)
            throw error
        }
    }

    /// Clear all undo and redo history
    func clearHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
        postUndoChangeNotification()
    }

    // MARK: - Private Methods

    /// Enforce history limit based on the current strategy
    private func enforceHistoryLimit() {
        switch historyLimit {
        case .unlimited:
            // No limits
            break

        case .fixedCount(let maxOps):
            // Keep only the most recent maxOps operations
            if undoStack.count > maxOps {
                undoStack.removeFirst(undoStack.count - maxOps)
            }

        case .timeWindow(let timeWindow):
            // Remove operations older than the time window
            let now = Date()
            let cutoffTime = now.addingTimeInterval(-timeWindow)

            // Remove operations older than cutoff
            while let firstOp = undoStack.first,
                  firstOp.timestamp < cutoffTime {
                undoStack.removeFirst()
            }

        case .hybrid(let maxOps, let timeWindow):
            // Apply both fixed count and time window limits
            let now = Date()
            let cutoffTime = now.addingTimeInterval(-timeWindow)

            // First, remove operations outside the time window
            while let firstOp = undoStack.first,
                  firstOp.timestamp < cutoffTime {
                undoStack.removeFirst()
            }

            // Then, enforce the maximum count
            if undoStack.count > maxOps {
                undoStack.removeFirst(undoStack.count - maxOps)
            }
        }
    }

    /// Post notification when undo/redo stacks change
    private func postUndoChangeNotification() {
        NotificationCenter.default.post(
            name: .undoStackDidChange,
            object: self,
            userInfo: [
                Notification.Name.canUndoKey: canUndo,
                Notification.Name.canRedoKey: canRedo
            ]
        )
    }
}
