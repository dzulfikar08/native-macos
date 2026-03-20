import XCTest
import AVFoundation
@testable import OpenScreen

final class WebcamRecordingSettingsTests: XCTestCase {
    func testDefaultSettingsValid() {
        let settings = WebcamRecordingSettings()
        XCTAssertFalse(settings.selectedCameras.isEmpty)
    }

    func testQualityPresets() {
        XCTAssertEqual(QualityPreset.low.framerate, 24.0)
        XCTAssertEqual(QualityPreset.medium.framerate, 30.0)
        XCTAssertEqual(QualityPreset.high.framerate, 30.0)
    }

    func testPipMode() {
        let single = PipMode.single
        let dual = PipMode.dual(main: 0, overlay: 1)
        let triple = PipMode.triple(main: 0, p2: 1, p3: 2)
        let quad = PipMode.quad

        // Test that modes can be compared
        XCTAssertEqual(single, .single)
        XCTAssertNotEqual(single, dual)
    }

    func testVideoCodecAvailability() {
        let codecs = VideoCodec.availableCodecs()
        XCTAssertTrue(codecs.contains(.h264))
        // HEVC requires macOS 10.13+
        if #available(macOS 10.13, *) {
            XCTAssertTrue(codecs.contains(.hevc))
        }
    }
}
