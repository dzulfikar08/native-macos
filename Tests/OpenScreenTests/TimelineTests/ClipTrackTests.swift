import XCTest
@testable import OpenScreen
import AVFoundation
import CoreMedia

@MainActor
final class ClipTrackTests: XCTestCase {
    func testClipTrackInitialization() {
        let track = ClipTrack(
            name: "Video 1",
            type: .video,
            zIndex: 0
        )

        XCTAssertEqual(track.name, "Video 1")
        XCTAssertEqual(track.type, .video)
        XCTAssertEqual(track.zIndex, 0)
        XCTAssertTrue(track.isEnabled)
        XCTAssertFalse(track.isLocked)
        XCTAssertTrue(track.isVisible)
        XCTAssertEqual(track.opacity, 1.0, accuracy: 0.01)
        XCTAssertTrue(track.clips.isEmpty)
    }

    func testAddClipMaintainsSortedOrder() {
        let track = ClipTrack(name: "Test", type: .video, zIndex: 0)
        let asset = TestDataFactory.makeTestAVAsset()

        let clip2 = TestDataFactory.makeTestVideoClip(
            name: "Clip 2",
            timelineStart: CMTime(seconds: 5, preferredTimescale: 600)
        )
        let clip1 = TestDataFactory.makeTestVideoClip(
            name: "Clip 1",
            timelineStart: .zero
        )

        track.addClip(clip2)  // Add at 5 seconds first
        track.addClip(clip1)  // Add at 0 seconds second

        XCTAssertEqual(track.clips.count, 2)
        XCTAssertEqual(track.clips.first?.name, "Clip 1")
        XCTAssertEqual(track.clips.last?.name, "Clip 2")
    }

    func testRemoveClip() {
        let track = ClipTrack(name: "Test", type: .video, zIndex: 0)
        let clip = TestDataFactory.makeTestVideoClip()

        track.addClip(clip)
        XCTAssertEqual(track.clips.count, 1)

        track.removeClip(id: clip.id)
        XCTAssertTrue(track.clips.isEmpty)
    }

    func testClipAtTimelineTime() {
        let track = ClipTrack(name: "Test", type: .video, zIndex: 0)
        let clip = TestDataFactory.makeTestVideoClip(
            timelineStart: .zero,
            sourceDuration: 10
        )

        track.addClip(clip)

        let foundClip = track.clip(at: CMTime(seconds: 5, preferredTimescale: 600))
        XCTAssertNotNil(foundClip)
        XCTAssertEqual(foundClip?.id, clip.id)
    }

    func testClipAtTimelineTimeNotFound() {
        let track = ClipTrack(name: "Test", type: .video, zIndex: 0)
        let clip = TestDataFactory.makeTestVideoClip(
            timelineStart: .zero,
            sourceDuration: 10
        )

        track.addClip(clip)

        let foundClip = track.clip(at: CMTime(seconds: 15, preferredTimescale: 600))
        XCTAssertNil(foundClip)
    }

    func testZIndexOrdering() {
        let track1 = ClipTrack(name: "Background", type: .video, zIndex: 0)
        let track2 = ClipTrack(name: "Foreground", type: .video, zIndex: 1)

        XCTAssertLess(track1.zIndex, track2.zIndex)
    }

    func testClipsInRange() {
        let track = ClipTrack(name: "Test", type: .video, zIndex: 0)
        let clip1 = TestDataFactory.makeTestVideoClip(
            timelineStart: .zero,
            sourceDuration: 5
        )
        let clip2 = TestDataFactory.makeTestVideoClip(
            timelineStart: CMTime(seconds: 10, preferredTimescale: 600),
            sourceDuration: 5
        )
        track.addClip(clip1)
        track.addClip(clip2)

        let range = CMTimeRange(
            start: .zero,
            end: CMTime(seconds: 8, preferredTimescale: 600)
        )
        let found = track.clips(in: range)

        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found.first?.id, clip1.id)
    }
}
