import XCTest
@testable import OpenScreen
import CoreMedia

@MainActor
final class Phase30FoundationIntegrationTests: XCTestCase {

    var editorState: EditorState!
    var clipManager: ClipManager!

    override func setUp() {
        super.setUp()
        editorState = EditorState.createTestState()
        clipManager = ClipManager(editorState: editorState)
    }

    override func tearDown() {
        editorState = nil
        clipManager = nil
        super.tearDown()
    }

    func testFullClipWorkflow() async {
        // Create a ClipTrack and add to state.clipTracks
        let track = ClipTrack(name: "Test Track", type: .video)
        editorState.clipTracks.append(track)

        // Create a test clip with 10 second duration
        let testClip = TestDataFactory.makeTestVideoClip(
            name: "Test Clip",
            speed: 1.0,
            sourceDuration: 10,
            timelineStart: .zero
        )

        // Add clip to track
        track.addClip(testClip)

        // Verify track.clips.count == 1
        XCTAssertEqual(track.clips.count, 1, "Track should have exactly 1 clip after adding")

        // Split clip at 5 seconds
        let splitTime = CMTime(seconds: 5, preferredTimescale: 600)
        XCTAssertNoThrow(try clipManager.splitClip(clipID: testClip.id, at: splitTime), "Should be able to split clip")

        // Verify track.clips.count == 2
        XCTAssertEqual(track.clips.count, 2, "Track should have 2 clips after splitting")

        // Get first clip and verify it has 5 second duration (from 0-5s)
        let firstClip = track.clips.first { $0.timeRangeInTimeline.start == .zero }
        XCTAssertNotNil(firstClip, "First clip should exist")
        XCTAssertEqual(firstClip?.timelineDuration.seconds, 5.0, "First clip should have 5 second duration")

        // Trim first clip to 3 seconds
        let trimRange = CMTimeRange(
            start: .zero,
            duration: CMTime(seconds: 3, preferredTimescale: 600)
        )
        XCTAssertNoThrow(try clipManager.trimClip(clipID: firstClip!.id, to: trimRange), "Should be able to trim clip")

        // Verify firstClip.timelineDuration == 3.0 seconds
        XCTAssertEqual(firstClip!.timelineDuration.seconds, 3.0, "First clip should be trimmed to 3 seconds")

        // Change first clip speed to 2.0
        XCTAssertNoThrow(try clipManager.changeClipSpeed(clipID: firstClip!.id, to: 2.0), "Should be able to change clip speed")

        // Verify firstClip.speed == 2.0
        XCTAssertEqual(firstClip!.speed, 2.0, "First clip speed should be 2.0")

        // Delete first clip
        XCTAssertNoThrow(try clipManager.deleteClip(clipID: firstClip!.id, ripple: false), "Should be able to delete clip")

        // Verify track.clips.count == 1
        XCTAssertEqual(track.clips.count, 1, "Track should have 1 clip after deleting first clip")
    }

  func testMultiTrackWorkflow() async {
        // Create two ClipTracks (track1 and track2)
        let track1 = ClipTrack(name: "Track 1", type: .video)
        let track2 = ClipTrack(name: "Track 2", type: .video)

        // Add both to state.clipTracks
        editorState.clipTracks = [track1, track2]

        // Create clip on track1 with 10 second duration
        let testClip = TestDataFactory.makeTestVideoClip(
            name: "Test Clip",
            speed: 1.0,
            sourceDuration: 10,
            timelineStart: .zero
        )

        // Add to track1
        track1.addClip(testClip)

        // Move clip to track2 at range [15s, 25s]
        let newRange = CMTimeRange(
            start: CMTime(seconds: 15, preferredTimescale: 600),
            duration: CMTime(seconds: 10, preferredTimescale: 600)
        )
        XCTAssertNoThrow(try clipManager.moveClip(
            clipID: testClip.id,
            to: newRange,
            on: track2.id,
            ripple: false
        ), "Should be able to move clip between tracks")

        // Verify clip.trackID == track2.id
        XCTAssertEqual(testClip.trackID, track2.id, "Clip should be on track2")

        // Verify track1.clips.isEmpty
        XCTAssertTrue(track1.clips.isEmpty, "Track1 should be empty after moving clip")

        // Verify track2.clips.count == 1
        XCTAssertEqual(track2.clips.count, 1, "Track2 should have 1 clip")
    }

    func testTimelineModeSwitching() {
        // Verify default timelineEditMode == .singleAsset
        XCTAssertEqual(editorState.timelineEditMode, .singleAsset, "Default timeline edit mode should be singleAsset")

        // Create ClipTrack and add to state.clipTracks
        let track = ClipTrack(name: "Test Track", type: .video)
        editorState.clipTracks.append(track)

        // Switch state.timelineEditMode to .multiClip
        editorState.timelineEditMode = .multiClip

        // Verify state.timelineEditMode == .multiClip
        XCTAssertEqual(editorState.timelineEditMode, .multiClip, "Timeline edit mode should be multiClip")
    }