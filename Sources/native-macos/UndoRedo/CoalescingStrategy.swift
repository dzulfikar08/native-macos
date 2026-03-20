import Foundation

/// Strategy for coalescing multiple operations into a single undoable action
enum CoalescingStrategy {
    case none                                    // No coalescing
    case timeWindow(TimeInterval)                // Merge operations within time window
    case sameTypeAndTarget                       // Merge same operation type on same target
    case smart                                   // Time window + type + target (default)
}

/// Configuration for coalescing behavior
struct CoalescingConfig {
    var timeWindow: TimeInterval = 1.0  // 1 second default
    var enabled: Bool = true
}
