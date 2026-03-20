import XCTest
@testable import OpenScreen

final class RecorderProtocolTests: XCTestCase {
    func testRecorderProtocolExists() {
        // This test verifies the protocol exists with correct signature
        let recorder: any Recorder = MockRecorder()
        XCTAssertTrue(recorder is Recorder)
    }

    func testRecorderHasIsRecording() {
        let recorder = MockRecorder()
        XCTAssertFalse(recorder.isRecording)
    }
}

final class MockRecorder: Recorder, @unchecked Sendable {
    typealias Config = MockConfig

    struct MockConfig: Sendable {
        let value: String
    }

    private let _isRecordingLock = NSLock()
    private var _isRecording = false

    func startRecording(to url: URL, config: MockConfig) async throws {
        _isRecordingLock.lock()
        _isRecording = true
        _isRecordingLock.unlock()
    }

    func stopRecording() async throws -> URL {
        _isRecordingLock.lock()
        _isRecording = false
        _isRecordingLock.unlock()
        return URL(fileURLWithPath: "/tmp/test.mov")
    }

    var isRecording: Bool {
        _isRecordingLock.lock()
        let result = _isRecording
        _isRecordingLock.unlock()
        return result
    }
}
