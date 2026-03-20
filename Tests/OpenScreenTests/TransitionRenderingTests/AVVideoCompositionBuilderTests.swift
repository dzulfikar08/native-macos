import XCTest
import AVFoundation
@testable import OpenScreen

@MainActor
final class AVVideoCompositionBuilderTests: XCTestCase {

    // MARK: - Test: Build Composition Without Transitions

    func testBuildCompositionNoTransitions() async throws {
        let editorState = EditorState.createTestState()

        // Add some clips
        let clips = try TestDataFactory.makeClipSequence(count: 3)
        let track = TestDataFactory.makeTestClipTrack(clips: clips)
        editorState.clipTracks = [track]

        let builder = AVVideoCompositionBuilder()
        let composition = try builder.buildComposition(for: editorState)

        XCTAssertNotNil(composition)
        XCTAssertEqual(composition?.instructions.count, 3) // One per clip

        // Verify each instruction has a valid time range
        for instruction in composition?.instructions ?? [] {
            XCTAssertTrue(instruction.timeRange.duration.isValid)
            XCTAssertGreaterThan(CMTimeGetSeconds(instruction.timeRange.duration), 0)
            XCTAssertLessThan(CMTimeCompare(instruction.timeRange.start, instruction.timeRange.end), 0)
        }
    }

    // MARK: - Test: Build Composition With Single Transition

    func testBuildCompositionWithTransition() async throws {
        let editorState = EditorState.createTestState()

        let (leading, trailing, _) = TestDataFactory.makeOverlappingClips()
        let track = TestDataFactory.makeTestClipTrack(clips: [leading, trailing])
        editorState.clipTracks = [track]

        // Add transition
        let transition = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 1.0, preferredTimescale: 600),
            leadingClipID: leading.id,
            trailingClipID: trailing.id
        )
        editorState.addTransition(transition)

        let builder = AVVideoCompositionBuilder()
        let composition = try builder.buildComposition(for: editorState)

        XCTAssertNotNil(composition)
        // Should have instructions for: before transition, during transition, after transition
        XCTAssertEqual(composition?.instructions.count, 3)

        // Verify all instructions have valid time ranges
        for instruction in composition?.instructions ?? [] {
            XCTAssertTrue(instruction.timeRange.duration.isValid)
            XCTAssertGreaterThan(CMTimeGetSeconds(instruction.timeRange.duration), 0)
            XCTAssertLessThan(CMTimeCompare(instruction.timeRange.start, instruction.timeRange.end), 0)
        }
    }

    // MARK: - Test: Build Composition With Multiple Transitions

    func testBuildCompositionMultipleTransitions() async throws {
        let editorState = EditorState.createTestState()

        // Create 3 clips with overlaps
        let clips = try TestDataFactory.makeOverlappingClipsSequence(count: 3)
        let track = TestDataFactory.makeTestClipTrack(clips: clips)
        editorState.clipTracks = [track]

        // Add transitions
        let transition1 = TransitionClip(
            type: .crossfade,
            duration: CMTime(seconds: 0.5, preferredTimescale: 600),
            leadingClipID: clips[0].id,
            trailingClipID: clips[1].id
        )

        let transition2 = TransitionClip(
            type: .wipe,
            duration: CMTime(seconds: 0.5, preferredTimescale: 600),
            leadingClipID: clips[1].id,
            trailingClipID: clips[2].id
        )

        editorState.addTransition(transition1)
        editorState.addTransition(transition2)

        let builder = AVVideoCompositionBuilder()
        let composition = try builder.buildComposition(for: editorState)

        XCTAssertNotNil(composition)
        XCTAssertEqual(composition?.instructions.count, 5) // clip, transition1, clip, transition2, clip

        // Verify all instructions have valid time ranges
        for instruction in composition?.instructions ?? [] {
            XCTAssertTrue(instruction.timeRange.duration.isValid)
            XCTAssertGreaterThan(CMTimeGetSeconds(instruction.timeRange.duration), 0)
            XCTAssertLessThan(CMTimeCompare(instruction.timeRange.start, instruction.timeRange.end), 0)
        }
    }
}
