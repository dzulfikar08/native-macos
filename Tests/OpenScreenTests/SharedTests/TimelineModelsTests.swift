import XCTest
@testable import OpenScreen
import CoreMedia

final class TimelineModelsTests: XCTestCase {
    func testTimelineTrackInitialization() {
        let track = TimelineTrack(
            id: UUID(),
            type: .video,
            name: "Video Track",
            height: 100
        )

        XCTAssertEqual(track.type, .video)
        XCTAssertEqual(track.name, "Video Track")
        XCTAssertEqual(track.height, 100)
    }

    func testThumbnailInitialization() {
        let time = CMTime(seconds: 1.0, preferredTimescale: 600)
        let thumbnail = Thumbnail(
            id: UUID(),
            time: time,
            texture: nil,
            isLoading: false
        )

        XCTAssertEqual(thumbnail.time, time)
        XCTAssertFalse(thumbnail.isLoading)
        XCTAssertNil(thumbnail.texture)
    }

    func testTrackLayoutInitialization() {
        let track = TimelineTrack(
            id: UUID(),
            type: .audio,
            name: "Audio",
            height: 60
        )
        let frame = CGRect(x: 0, y: 0, width: 800, height: 60)
        let positions: [CMTime: CGFloat] = [:]

        let layout = TrackLayout(
            track: track,
            frame: frame,
            thumbnailPositions: positions
        )

        XCTAssertEqual(layout.track.name, "Audio")
        XCTAssertEqual(layout.frame, frame)
        XCTAssertTrue(layout.thumbnailPositions.isEmpty)
    }

    func testTimelineErrorDescriptions() {
        let notLoadedError = TimelineError.videoNotLoaded
        XCTAssertEqual(notLoadedError.localizedDescription, "No video is currently loaded")

        let invalidRangeError = TimelineError.invalidTimeRange
        XCTAssertTrue(invalidRangeError.localizedDescription.contains("Invalid time range"))
    }
}
