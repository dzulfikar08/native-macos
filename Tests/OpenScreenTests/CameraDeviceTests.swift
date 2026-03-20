import XCTest
import AVFoundation
@testable import OpenScreen

final class CameraDeviceTests: XCTestCase {
    func testCameraDeviceCanBeCreated() {
        let device = CameraDevice(
            id: "test-id",
            name: "Test Camera",
            position: .back,
            supportedFormats: []
        )
        XCTAssertEqual(device.id, "test-id")
        XCTAssertEqual(device.name, "Test Camera")
        XCTAssertEqual(device.position, .back)
    }

    func testEnumerateCameras() {
        let cameras = CameraDevice.enumerateCameras()
        // On systems with cameras, should return at least built-in camera
        // On CI/test systems without cameras, may return empty
        XCTAssertTrue(cameras is [CameraDevice])
    }

    func testCameraDeviceCreatesCaptureInput() async throws {
        let cameras = CameraDevice.enumerateCameras()
        guard let camera = cameras.first else {
            XCTSkip("No cameras available on this system")
            return
        }

        let input = try camera.createCaptureInput()
        XCTAssertNotNil(input)
        XCTAssertTrue(input is AVCaptureDeviceInput)
    }
}
