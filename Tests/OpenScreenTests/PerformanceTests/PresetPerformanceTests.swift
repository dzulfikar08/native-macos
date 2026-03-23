import XCTest
import CoreMedia
@testable import OpenScreen

final class PresetPerformanceTests: XCTestCase {

    var library: PresetLibrary!
    var storage: TransitionPresetStorage!

    override func setUp() async throws {
        try await super.setUp()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("preset_perf_\(UUID().uuidString)")
        storage = TransitionPresetStorage(directory: tempDir)
        library = PresetLibrary(storage: storage)
    }

    func testLibraryLoadTimeWith100Presets() throws {
        // Create 100 custom presets
        for i in 0..<100 {
            let transition = TransitionClip(
                type: .crossfade,
                duration: CMTime(seconds: Double(i) * 0.01 + 0.5, preferredTimescale: 600),
                leadingClipID: UUID(),
                trailingClipID: UUID(),
                parameters: .crossfade,
                isEnabled: true
            )

            try library.savePreset(
                name: "Performance Preset \(i)",
                folder: i % 5 == 0 ? "Performance Tests" : "",
                transition: transition,
                isFavorite: i % 10 == 0
            )
        }

        // Measure load time
        measure {
            let newLibrary = PresetLibrary(storage: storage)
            try? newLibrary.loadCustomPresets()
            XCTAssertEqual(newLibrary.allPresets.count, 105) // 5 built-in + 100 custom
        }
    }

    func testThumbnailGenerationPerformance() {
        // Create a preset
        let transition = TransitionClip(
            type: .wipe,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: UUID(),
            trailingClipID: UUID(),
            parameters: .wipe(direction: .left, softness: 0.5, border: 0),
            isEnabled: true
        )

        try! library.savePreset(
            name: "Thumbnail Perf Test",
            folder: "",
            transition: transition,
            isFavorite: false
        )

        guard let preset = library.allPresets.first(where: { $0.name == "Thumbnail Perf Test" }) else {
            XCTFail("Preset not found")
            return
        }

        // Measure thumbnail generation time
        var renderer = PresetPreviewRenderer()
        measure {
            _ = renderer.thumbnail(for: preset, storage: storage)
        }
    }

    func testPresetManagerWindowLoadTime() {
        // This test ensures the preset manager window can load quickly
        measure {
            let window = PresetManagerWindow()
            _ = window.displayedPresets
            // Window should be able to initialize and display presets quickly
            XCTAssertGreaterThan(window.displayedPresets.count, 0)
        }
    }
}
