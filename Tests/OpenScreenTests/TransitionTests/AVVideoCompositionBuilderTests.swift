import XCTest
import AVFoundation
@testable import OpenScreen

@MainActor
final class AVVideoCompositionBuilderTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Clear any previous editor state
        TransitionVideoCompositor.clearEditorState()
    }

    override func tearDown() {
        // Clean up editor state after each test
        TransitionVideoCompositor.clearEditorState()
        super.tearDown()
    }

    // MARK: - Task 4.1 Tests

    // Test 1: Verify custom compositor class is set
    func testBuildCompositionSetsCustomCompositor() async throws {
        let editorState = EditorState.createTestState()

        let clips = try TestDataFactory.makeClipSequence(count: 2)
        let track = TestDataFactory.makeTestClipTrack(clips: clips)
        editorState.clipTracks = [track]

        let builder = AVVideoCompositionBuilder()
        let composition = try builder.buildComposition(for: editorState)

        XCTAssertNotNil(composition)
        XCTAssertEqual(
            composition?.customVideoCompositorClass,
            TransitionVideoCompositor.self
        )
    }

    // Test 2: Verify draft quality settings are applied
    func testBuildCompositionWithDraftQuality() async throws {
        let editorState = EditorState.createTestState()

        let clips = try TestDataFactory.makeClipSequence(count: 2)
        let track = TestDataFactory.makeTestClipTrack(clips: clips)
        editorState.clipTracks = [track]

        let builder = AVVideoCompositionBuilder()
        let composition = try builder.buildComposition(
            for: editorState,
            quality: .draft
        )

        XCTAssertNotNil(composition)
        XCTAssertEqual(composition?.renderSize.width, 1280)
        XCTAssertEqual(composition?.renderSize.height, 720)
    }

    // Test 3: Verify best quality settings use source resolution
    func testBuildCompositionWithBestQuality() async throws {
        let editorState = EditorState.createTestState()

        let clips = try TestDataFactory.makeClipSequence(count: 2)
        let track = TestDataFactory.makeTestClipTrack(clips: clips)
        editorState.clipTracks = [track]

        let builder = AVVideoCompositionBuilder()
        let composition = try builder.buildComposition(
            for: editorState,
            quality: .best
        )

        XCTAssertNotNil(composition)
        // Best quality should use source resolution (first clip's natural size)
        let expectedSize = renderSize(for: editorState)
        XCTAssertEqual(composition?.renderSize.width, expectedSize.width)
        XCTAssertEqual(composition?.renderSize.height, expectedSize.height)
    }

    // Test 4: Verify transition instructions are created
    func testBuildCompositionCreatesTransitionInstructions() async throws {
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
        XCTAssertGreaterThan(composition?.instructions.count ?? 0, 0)

        // Find transition instruction
        let transitionInstruction = composition?.instructions.first { instruction in
            instruction is TransitionVideoCompositionInstruction
        }

        XCTAssertNotNil(
            transitionInstruction,
            "Should create TransitionVideoCompositionInstruction for transitions"
        )

        if let transitionInstruction = transitionInstruction as? TransitionVideoCompositionInstruction {
            XCTAssertEqual(transitionInstruction.transitionID, transition.id)
            XCTAssertEqual(transitionInstruction.transitionType, "crossfade")
        }
    }

    // Test 5: Verify composition works with no transitions
    func testBuildCompositionWithNoTransitions() async throws {
        let editorState = EditorState.createTestState()

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

    // MARK: - Original Tests (Preserved)

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

    // MARK: - Helper Methods

    private func renderSize(for editorState: EditorState) -> CGSize {
        // Use first video clip's asset to determine size
        if let firstClip = editorState.clipTracks
            .filter({ $0.type == .video })
            .flatMap({ $0.clips })
            .first {
            let asset = firstClip.asset
            let track = asset.tracks(withMediaType: .video).first
            return track?.naturalSize ?? CGSize(width: 1920, height: 1080)
        }
        return CGSize(width: 1920, height: 1080)
    }
}
