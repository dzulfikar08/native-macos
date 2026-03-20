import Foundation
import AVFoundation
import CoreMedia

/// Protocol for undoable clip operations
@MainActor
protocol ClipOperation {
    /// Human-readable description of this operation
    var description: String { get }

    /// When this operation was created (for coalescing and history limits)
    var timestamp: Date { get }

    /// Execute the operation
    func execute() throws

    /// Undo the operation
    func undo() throws

    /// Redo the operation (default uses execute())
    func redo() throws
}

/// Base class for clip operations with undo/redo support
@MainActor
class BaseClipOperation: ClipOperation {
    let description: String
    weak var editorState: EditorState?
    weak var clipManager: ClipManager?

    /// When this operation was created (for coalescing and history limits)
    let timestamp: Date

    init(description: String, editorState: EditorState, clipManager: ClipManager? = nil) {
        self.description = description
        self.editorState = editorState
        self.clipManager = clipManager
        self.timestamp = Date()
    }

    func execute() throws {
        fatalError("Subclasses must implement execute()")
    }

    func undo() throws {
        fatalError("Subclasses must implement undo()")
    }

    func redo() throws {
        try execute()
    }
}
