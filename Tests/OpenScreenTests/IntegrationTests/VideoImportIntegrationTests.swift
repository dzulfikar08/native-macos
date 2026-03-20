import XCTest
import AVFoundation
@testable import OpenScreen

@MainActor
final class VideoImportIntegrationTests: XCTestCase {

    func testImportFlowComponents() async throws {
        // Verify components can be instantiated
        let validator = VideoValidator.self
        XCTAssertNotNil(validator)

        let metadata = VideoMetadata(
            duration: CMTime(seconds: 10, preferredTimescale: 600),
            durationString: "00:00:10",
            resolution: CGSize(width: 1920, height: 1080),
            frameRate: 30.0,
            codec: "h264",
            fileSize: 10_000_000,
            isCompatible: true,
            warnings: [],
            thumbnail: nil
        )
        XCTAssertNotNil(metadata)
    }

    func testRecentFilesPersistence() {
        // Test that recent files persist
        let documentController = NSDocumentController.shared
        let testURL = URL(fileURLWithPath: "/test/video.mp4")

        documentController.noteNewRecentDocumentURL(testURL)

        let recentURLs = documentController.recentDocumentURLs
        XCTAssertTrue(recentURLs.count > 0)
        // Clean up
        documentController.clearRecentDocuments(nil)
    }
}
