import XCTest
@testable import OpenScreen

@MainActor
final class WindowRecordingSettingsTests: XCTestCase {
    func testSettingsValidationWithValidData() {
        let windows = [
            WindowDevice(id: 1, name: "W1", ownerName: "App", bounds: .zero),
            WindowDevice(id: 2, name: "W2", ownerName: "App", bounds: .zero)
        ]

        var settings = WindowRecordingSettings()
        settings.selectedWindows = windows
        settings.qualityPreset = .high
        settings.compositingMode = .dual(main: 0, overlay: 1)
        settings.codec = .h264
        settings.audioSettings = AudioSettings()

        XCTAssertTrue(settings.isValid)
    }

    func testSettingsValidationWithNoWindows() {
        var settings = WindowRecordingSettings()
        settings.qualityPreset = .high
        settings.compositingMode = .single

        XCTAssertFalse(settings.isValid, "Should be invalid with no windows")
    }

    func testSettingsValidationWithTooManyWindows() {
        let windows = [
            WindowDevice(id: 1, name: "W1", ownerName: "App", bounds: .zero),
            WindowDevice(id: 2, name: "W2", ownerName: "App", bounds: .zero),
            WindowDevice(id: 3, name: "W3", ownerName: "App", bounds: .zero),
            WindowDevice(id: 4, name: "W4", ownerName: "App", bounds: .zero),
            WindowDevice(id: 5, name: "W5", ownerName: "App", bounds: .zero)
        ]

        var settings = WindowRecordingSettings()
        settings.selectedWindows = windows
        settings.compositingMode = .quad

        XCTAssertFalse(settings.isValid, "Should be invalid with more than 4 windows")
    }
}
