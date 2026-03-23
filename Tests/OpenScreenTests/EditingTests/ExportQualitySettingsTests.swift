import XCTest
@testable import OpenScreen

final class ExportQualitySettingsTests: XCTestCase {

    func testDraftQualitySettings() {
        let draft = ExportQualitySettings.draft

        XCTAssertEqual(draft.preset, .draft)
        XCTAssertEqual(draft.renderSize, CGSize(width: 1280, height: 720))
        XCTAssertEqual(draft.bitrate, 5)
        XCTAssertEqual(draft.antiAliasing, .none)
    }

    func testGoodQualitySettings() {
        let good = ExportQualitySettings.good

        XCTAssertEqual(good.preset, .good)
        XCTAssertEqual(good.renderSize, CGSize(width: 1920, height: 1080))
        XCTAssertEqual(good.bitrate, 15)
        XCTAssertEqual(good.antiAliasing, .basic)
    }

    func testBestQualitySettings() {
        let best = ExportQualitySettings.best

        XCTAssertEqual(best.preset, .best)
        XCTAssertNil(best.renderSize) // Source resolution
        XCTAssertEqual(best.bitrate, 30)
        XCTAssertEqual(best.antiAliasing, .multiSample)
    }

    func testCustomQualitySettings() {
        let custom = ExportQualitySettings(
            preset: .custom,
            renderSize: CGSize(width: 3840, height: 2160),
            bitrate: 50,
            antiAliasing: .multiSample
        )

        XCTAssertEqual(custom.preset, .custom)
        XCTAssertEqual(custom.renderSize, CGSize(width: 3840, height: 2160))
        XCTAssertEqual(custom.bitrate, 50)
        XCTAssertEqual(custom.antiAliasing, .multiSample)
    }

    func testQualityPresetRawValues() {
        XCTAssertEqual(ExportQualityPreset.draft.rawValue, "draft")
        XCTAssertEqual(ExportQualityPreset.good.rawValue, "good")
        XCTAssertEqual(ExportQualityPreset.best.rawValue, "best")
        XCTAssertEqual(ExportQualityPreset.custom.rawValue, "custom")
    }

    func testAntiAliasingModeRawValues() {
        XCTAssertEqual(ExportQualitySettings.AntiAliasingMode.none.rawValue, "none")
        XCTAssertEqual(ExportQualitySettings.AntiAliasingMode.basic.rawValue, "basic")
        XCTAssertEqual(ExportQualitySettings.AntiAliasingMode.multiSample.rawValue, "multiSample")
    }

    func testCodableConformance() {
        let original = ExportQualitySettings.good
        let encoder = JSONEncoder()
        let data = try! encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try! decoder.decode(ExportQualitySettings.self, from: data)

        XCTAssertEqual(decoded.preset, original.preset)
        XCTAssertEqual(decoded.renderSize, original.renderSize)
        XCTAssertEqual(decoded.bitrate, original.bitrate)
        XCTAssertEqual(decoded.antiAliasing, original.antiAliasing)
    }
}