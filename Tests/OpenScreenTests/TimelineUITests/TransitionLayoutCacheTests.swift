import XCTest
import CoreGraphics
import CoreMedia
@testable import OpenScreen

@MainActor
final class TransitionLayoutCacheTests: XCTestCase {
    var cache: TransitionLayoutCache!
    var clipLayoutCache: ClipLayoutCache!
    var track: ClipTrack!

    override func setUp() async throws {
        try await super.setUp()
        cache = TransitionLayoutCache()
        clipLayoutCache = ClipLayoutCache()

        let (leading, trailing, _) = TestDataFactory.makeOverlappingClipsWithTransition()
        track = TestDataFactory.makeTestClipTrack(clips: [leading, trailing])
    }

    // MARK: - Frame Calculation Tests

    func testTransitionFrameCalculation() {
        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: track.clips[0].id,
            trailingClipID: track.clips[1].id
        )

        let frame = cache.transitionFrame(for: transition, in: track, clipLayoutCache: clipLayoutCache)

        XCTAssertNotNil(frame)
        XCTAssertFalse(frame!.isEmpty)
    }

    func testTransitionFrameCaching() {
        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: track.clips[0].id,
            trailingClipID: track.clips[1].id
        )

        let frame1 = cache.transitionFrame(for: transition, in: track, clipLayoutCache: clipLayoutCache)
        let frame2 = cache.transitionFrame(for: transition, in: track, clipLayoutCache: clipLayoutCache)

        XCTAssertEqual(frame1, frame2, "Should return cached frame")
    }

    func testInvalidateTransition() {
        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: track.clips[0].id,
            trailingClipID: track.clips[1].id
        )

        _ = cache.transitionFrame(for: transition, in: track, clipLayoutCache: clipLayoutCache)
        cache.invalidateTransition(transitionID: transition.id)

        let cached = cache.cachedLayout(for: transition)
        XCTAssertNil(cached, "Should be invalidated")
    }

    // MARK: - Drag Handle Tests

    func testLeadingDragHandleFrame() {
        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: track.clips[0].id,
            trailingClipID: track.clips[1].id
        )

        let handleFrame = cache.dragHandleFrame(
            for: transition,
            edge: .leading,
            in: track,
            clipLayoutCache: clipLayoutCache
        )

        XCTAssertNotNil(handleFrame)
        XCTAssertEqual(handleFrame?.width, 10)
    }

    func testTrailingDragHandleFrame() {
        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: track.clips[0].id,
            trailingClipID: track.clips[1].id
        )

        let handleFrame = cache.dragHandleFrame(
            for: transition,
            edge: .trailing,
            in: track,
            clipLayoutCache: clipLayoutCache
        )

        XCTAssertNotNil(handleFrame)
        XCTAssertEqual(handleFrame?.width, 10)
    }

    func testNonOverlappingClipsReturnNil() {
        let (leading, trailing, _) = TestDataFactory.makeNonOverlappingClipsWithTransition()
        let track = TestDataFactory.makeTestClipTrack(clips: [leading, trailing])

        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: leading.id,
            trailingClipID: trailing.id
        )

        let frame = cache.transitionFrame(for: transition, in: track, clipLayoutCache: clipLayoutCache)

        // When clips don't overlap, transitionFrame should return nil
        XCTAssertNil(frame, "Non-overlapping clips should return nil frame")
    }

    func testInvalidateAll() {
        let transition1 = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: track.clips[0].id,
            trailingClipID: track.clips[1].id
        )

        let transition2 = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: track.clips[0].id,
            trailingClipID: track.clips[1].id
        )

        // Cache both transitions
        _ = cache.transitionFrame(for: transition1, in: track, clipLayoutCache: clipLayoutCache)
        _ = cache.transitionFrame(for: transition2, in: track, clipLayoutCache: clipLayoutCache)

        cache.invalidateAll()

        XCTAssertNil(cache.cachedLayout(for: transition1))
        XCTAssertNil(cache.cachedLayout(for: transition2))
    }
}
