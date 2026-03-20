import Foundation

/// Strategy for limiting undo/redo history to prevent unbounded memory growth
enum HistoryLimit {
    case unlimited                              // Keep all operations
    case fixedCount(Int)                        // Max N operations
    case timeWindow(TimeInterval)               // Keep operations within time window (seconds)
    case hybrid(maxOps: Int, timeWindow: TimeInterval)  // Soft limit + time window (default)
}
