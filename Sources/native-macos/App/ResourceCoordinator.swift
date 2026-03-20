import Foundation
import AppKit

/// Monitors system resources and responds to pressure events
@MainActor
final class ResourceCoordinator {
    private var memoryPressureObserver: NSObjectProtocol?
    private var gpuStatusObserver: NSObjectProtocol?

    /// Starts monitoring system resources
    func startMonitoring() {
        monitorMemoryPressure()
        monitorGPUStatus()
    }

    /// Stops monitoring system resources
    func stopMonitoring() {
        if let observer = memoryPressureObserver {
            NotificationCenter.default.removeObserver(observer)
            memoryPressureObserver = nil
        }
        if let observer = gpuStatusObserver {
            NotificationCenter.default.removeObserver(observer)
            gpuStatusObserver = nil
        }
    }

    /// Monitors memory pressure events
    private func monitorMemoryPressure() {
        // macOS doesn't have a memory warning notification like iOS
        // Instead, we'll use DispatchSource to monitor memory pressure
        // For Phase 1, we'll use a simpler approach with periodic checks
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.checkMemoryPressure()
        }
    }

    /// Checks memory pressure periodically
    private func checkMemoryPressure() {
        let usage = currentMemoryUsage()
        // If using more than 1GB, trigger warning
        if usage > 1_000_000_000 {
            handleMemoryWarning()
        }
    }

    /// Monitors GPU status (placeholder for Phase 2)
    private func monitorGPUStatus() {
        // GPU monitoring will be implemented in Phase 2 when Metal rendering is added
        // For now, we'll just log GPU availability
        #if arch(arm64)
        print("✅ Apple Silicon GPU detected")
        #else
        print("⚠️ Intel Mac - GPU capabilities may vary")
        #endif
    }

    /// Handles memory warning notifications
    private func handleMemoryWarning() {
        print("⚠️ Memory warning received - clearing caches")
        // Notify observers to clear caches
        NotificationCenter.default.post(
            name: NSNotification.Name("ClearCaches"),
            object: nil
        )
    }

    /// Returns current memory usage in bytes
    func currentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        return result == KERN_SUCCESS ? info.resident_size : 0
    }
}
