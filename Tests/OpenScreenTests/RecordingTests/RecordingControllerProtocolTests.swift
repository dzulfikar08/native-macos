import XCTest
@testable import OpenScreen

@MainActor
final class RecordingControllerProtocolTests: XCTestCase {
    func testRecordingControllerAcceptsRecorder() async throws {
        let controller = RecordingController()
        let mockRecorder = MockRecorderForController()
        let config = MockRecorderForController.Config(value: "test")
        let url = URL(fileURLWithPath: "/tmp/mock_output.mov")

        let outputURL = try await controller.startRecording(with: mockRecorder, config: config)

        XCTAssertEqual(outputURL.path, "/tmp/mock_output.mov")
        XCTAssertTrue(mockRecorder.isRecording)
    }
}

@MainActor
class MockRecorderForController: Recorder {
    typealias Config = MockConfig

    struct MockConfig: Sendable {
        let value: String
    }

    private var _isRecording = false
    private var recordedURL: URL?

    func startRecording(to url: URL, config: MockConfig) async throws {
        _isRecording = true
        recordedURL = url
    }

    func stopRecording() async throws -> URL {
        _isRecording = false
        return recordedURL ?? URL(fileURLWithPath: "/tmp/fallback.mov")
    }

    var isRecording: Bool { _isRecording }
}
