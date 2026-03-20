import XCTest
@testable import OpenScreen

final class SourceSelectionTests: XCTestCase {
    func testSourceSelectionScreen() {
        // Create a screen selection
        let selection = SourceSelection.screen(displayID: 123, displayName: "Main Display")

        // Verify the selection stores the correct values
        switch selection {
        case .screen(let displayID, let displayName):
            XCTAssertEqual(displayID, 123, "DisplayID should match")
            XCTAssertEqual(displayName, "Main Display", "DisplayName should match")
        default:
            XCTFail("Expected .screen case")
        }
    }

    func testSourceSelectionVideoFile() {
        // Create a video file selection
        let testURL = URL(fileURLWithPath: "/tmp/test-video.mp4")
        let selection = SourceSelection.videoFile(url: testURL)

        // Verify the selection stores the correct URL
        switch selection {
        case .videoFile(let url):
            XCTAssertEqual(url, testURL, "URL should match")
        default:
            XCTFail("Expected .videoFile case")
        }
    }
}
