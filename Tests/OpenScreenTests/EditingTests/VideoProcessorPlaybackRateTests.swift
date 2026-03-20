import XCTest
@testable import OpenScreen

@MainActor
final class VideoProcessorPlaybackRateTests: XCTestCase {

    var videoProcessor: VideoProcessor!
    var mockEditorState: MockEditorState!

    override func setUp() async throws {
        let url = TestDataFactory.makeTestRecordingURL()
        videoProcessor = VideoProcessor(assetURL: url)
        mockEditorState = MockEditorState()
    }

    override func tearDown() async throws {
        videoProcessor = nil
        mockEditorState = nil
    }

    // MARK: - Playback Rate Initialization Tests

    func testVideoProcessorInitializesWithDefaultRate() {
        XCTAssertEqual(videoProcessor.playbackRate, 1.0)
    }

    func testCanSetPlaybackRateWithinValidRange() {
        let testRates: [Float] = [-4.0, -2.0, -1.0, 0.5, 1.0, 2.0, 4.0]

        for rate in testRates {
            videoProcessor.setPlaybackRate(rate)
            XCTAssertEqual(videoProcessor.playbackRate, rate)
        }
    }

    func testRejectsPlaybackRateOutsideValidRange() {
        let invalidRates: [Float] = [-5.0, -4.1, 4.1, 5.0]

        for rate in invalidRates {
            videoProcessor.setPlaybackRate(rate)
            // Should clamp to nearest valid value
            if rate < -4.0 {
                XCTAssertEqual(videoProcessor.playbackRate, -4.0)
            } else {
                XCTAssertEqual(videoProcessor.playbackRate, 4.0)
            }
        }
    }

    // MARK: - Frame Skip Counting Tests

    func testFrameSkipCountingForNormalSpeed() {
        videoProcessor.setPlaybackRate(1.0)
        videoProcessor.incrementFrameSkipCount()
        XCTAssertEqual(videoProcessor.frameSkipCount, 0) // No skip at normal speed
    }

    func testFrameSkipCountingFor2xSpeed() {
        videoProcessor.setPlaybackRate(2.0)
        videoProcessor.incrementFrameSkipCount()
        XCTAssertEqual(videoProcessor.frameSkipCount, 1)
        videoProcessor.incrementFrameSkipCount()
        XCTAssertEqual(videoProcessor.frameSkipCount, 2)
    }

    func testFrameSkipCountingFor4xSpeed() {
        videoProcessor.setPlaybackRate(4.0)
        videoProcessor.incrementFrameSkipCount()
        XCTAssertEqual(videoProcessor.frameSkipCount, 1)
        videoProcessor.incrementFrameSkipCount()
        XCTAssertEqual(videoProcessor.frameSkipCount, 2)
    }

    func testFrameSkipCountingForReverseSpeeds() {
        videoProcessor.setPlaybackRate(-2.0)
        videoProcessor.incrementFrameSkipCount()
        XCTAssertEqual(videoProcessor.frameSkipCount, 1)
        videoProcessor.incrementFrameSkipCount()
        XCTAssertEqual(videoProcessor.frameSkipCount, 2)
    }

    func testFrameSkipCountingResetsAtNormalSpeed() {
        videoProcessor.setPlaybackRate(2.0)
        videoProcessor.incrementFrameSkipCount()
        videoProcessor.incrementFrameSkipCount()
        XCTAssertEqual(videoProcessor.frameSkipCount, 2)

        videoProcessor.setPlaybackRate(1.0)
        XCTAssertEqual(videoProcessor.frameSkipCount, 0)
    }

    // MARK: - Loop Boundary Checking Tests

    func testCheckLoopBoundaryNormalPlayback() {
        let testCases: [(rate: Float, inPoint: CMTime?, outPoint: CMTime?, time: CMTime, expectedResult: Bool)] = [
            (1.0, nil, nil, .seconds(5), false),
            (1.0, .seconds(10), .seconds(20), .seconds(15), false),
            (1.0, .seconds(10), .seconds(20), .seconds(5), true), // Before in-point
            (1.0, .seconds(10), .seconds(20), .seconds(25), true), // After out-point
        ]

        for (rate, inPoint, outPoint, time, expected) in testCases {
            mockEditorState.inPoint = inPoint
            mockEditorState.outPoint = outPoint
            videoProcessor.setPlaybackRate(rate)

            let result = videoProcessor.checkLoopBoundary(time: time, editorState: mockEditorState)
            XCTAssertEqual(result, expected, "Rate: \(rate), Time: \(CMTimeGetSeconds(time)), In: \(inPoint?.seconds ?? 0), Out: \(outPoint?.seconds ?? 0)")
        }
    }

    func testCheckLoopBoundaryReversePlayback() {
        let testCases: [(rate: Float, inPoint: CMTime?, outPoint: CMTime?, time: CMTime, expectedResult: Bool)] = [
            (-2.0, nil, nil, .seconds(5), false),
            (-2.0, .seconds(10), .seconds(20), .seconds(15), false),
            (-2.0, .seconds(10), .seconds(20), .seconds(12), true), // Hit loop boundary in reverse
        ]

        for (rate, inPoint, outPoint, time, expected) in testCases {
            mockEditorState.inPoint = inPoint
            mockEditorState.outPoint = outPoint
            videoProcessor.setPlaybackRate(rate)

            let result = videoProcessor.checkLoopBoundary(time: time, editorState: mockEditorState)
            XCTAssertEqual(result, expected, "Rate: \(rate), Time: \(CMTimeGetSeconds(time)), In: \(inPoint?.seconds ?? 0), Out: \(outPoint?.seconds ?? 0)")
        }
    }

    // MARK: - Audio Rate Handling Tests

    func testAudioRateAppliedCorrectly() {
        videoProcessor.setPlaybackRate(2.0)
        XCTAssertEqual(videoProcessor.audioRate, 2.0)

        videoProcessor.setPlaybackRate(-2.0)
        XCTAssertEqual(videoProcessor.audioRate, -2.0)

        videoProcessor.setPlaybackRate(0.5)
        XCTAssertEqual(videoProcessor.audioRate, 0.5)
    }

    // MARK: - Rate Change Notification Tests

    func testObservesPlaybackRateChanges() {
        let initialRate = videoProcessor.playbackRate

        // Simulate rate change in editor state
        mockEditorState.playbackRate = 2.0

        // After observing changes, processor should sync
        videoProcessor.observePlaybackRate(editorState: mockEditorState)
        XCTAssertEqual(videoProcessor.playbackRate, 2.0)
    }

    func testObservesPlaybackRateFromInitialValue() {
        XCTAssertEqual(videoProcessor.playbackRate, 1.0)

        mockEditorState.playbackRate = -1.5
        videoProcessor.observePlaybackRate(editorState: mockEditorState)
        XCTAssertEqual(videoProcessor.playbackRate, -1.5)
    }
}

// MARK: - Mock Editor State

@MainActor
class MockEditorState: ObservableObject {
    @Published var playbackRate: Float = 1.0
    @Published var inPoint: CMTime?
    @Published var outPoint: CMTime?

    var currentTime: CMTime = .zero
}