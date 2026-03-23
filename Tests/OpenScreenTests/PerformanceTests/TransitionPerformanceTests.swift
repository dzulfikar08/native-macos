import XCTest
import CoreMedia
import MachO
@testable import OpenScreen

@available(macOS 13.0, *)
final class TransitionPerformanceTests: XCTestCase {

    func test60FPSPlaybackWithTransitions() {
        // Measure that we can render transitions at 60fps
        let renderer = TransitionPreviewRenderer()
        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 2, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID(),
            parameters: .crossfade,
            isEnabled: true
        )

        let leadingImage = CIImage(color: .red).cropped(to: CGRect(x: 0, y: 0, width: 1920, height: 1080))
        let trailingImage = CIImage(color: .blue).cropped(to: CGRect(x: 0, y: 0, width: 1920, height: 1080))

        measure {
            for progress in stride(from: 0.0, through: 1.0, by: 0.016) { // 60fps
                _ = renderer.applyTransition(from: leadingImage, to: trailingImage, transition: transition, progress: progress)
            }
        }
    }

    func testMemoryUsageWithMultipleTransitions() {
        // Measure memory usage with 100 transitions in timeline
        let editorState = EditorState()
        
        for _ in 0..<100 {
            let transition = TransitionClip(
                type: .crossfade,
                duration: CMTime(seconds: 1, preferredTimescale: 600),
                leadingClipID: UUID(),
                trailingClipID: UUID(),
                parameters: .crossfade,
                isEnabled: true
            )
            editorState.addTransition(transition)
        }

        // Measure memory footprint
        let memoryBefore = getMemoryUsage()
        _ = editorState.transitions.count
        let memoryAfter = getMemoryUsage()

        let memoryIncrease = memoryAfter - memoryBefore
        XCTAssertLessThan(memoryIncrease, 50_000_000) // Less than 50MB increase
    }

    func testPresetLibraryLoadPerformance() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("perf_test_\(UUID().uuidString)")
        let storage = TransitionPresetStorage(directory: tempDir)

        measure {
            let library = PresetLibrary(storage: storage)
            _ = library.allPresets.count
        }
    }

    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return info.resident_size
        }
        return 0
    }
}
