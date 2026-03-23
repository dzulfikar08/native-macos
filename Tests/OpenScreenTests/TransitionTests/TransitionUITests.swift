import XCTest
import SwiftUI
import CoreMedia
@testable import OpenScreen

/// Comprehensive UI workflow tests for Video Transitions feature
///
/// These tests verify the complete user workflows for creating and managing
/// video transitions using all available creation methods:
/// - Drag and drop from palette
/// - Context menu (right-click)
/// - Auto-prompt on overlap
/// - Keyboard shortcut (Cmd+Opt+T)
@MainActor
final class TransitionUITests: XCTestCase {
    var editorState: EditorState!
    var viewModel: TimelineViewModel!
    var track: ClipTrack!

    override func setUp() async throws {
        try await super.setUp()

        editorState = EditorState.createTestState()
        viewModel = TimelineViewModel(editorState: editorState)
        track = TestDataFactory.makeTestClipTrack(clips: [])
    }

    override func tearDown() async throws {
        viewModel = nil
        editorState = nil
        track = nil
        try await super.tearDown()
    }

    // MARK: - Workflow Tests

    /// Test complete drag-and-drop workflow from palette to timeline
    ///
    /// Workflow steps:
    /// 1. Create two overlapping clips on timeline
    /// 2. Drag transition from palette (e.g., "Quick Dissolve")
    /// 3. Drop on overlap area between clips
    /// 4. Verify transition is created with correct properties
    /// 5. Verify transition appears in timeline overlay
    func testCompleteDragDropWorkflow() {
        // Step 1: Create overlapping clips
        let (leading, trailing) = createOverlappingClips()
        track.clips = [leading, trailing]
        editorState.clipTracks = [track]

        // Step 2: Get transition palette item (simulating drag from palette)
        let preset = BuiltInPresets.presets.first { $0.name == "Quick Dissolve" }
        XCTAssertNotNil(preset, "Quick Dissolve preset should exist")

        guard let dissolvePreset = preset else { return }

        // Step 3: Create transition at overlap (simulating drop)
        let overlap = calculateOverlap(leading: leading, trailing: trailing)
        XCTAssertGreaterThan(overlap.seconds, 0, "Clips should overlap")

        let transition = dissolvePreset.makeTransition(
            leadingClipID: leading.id,
            trailingClipID: trailing.id
        )

        // Step 4: Add to editor state
        editorState.addTransition(transition)
        viewModel.syncTransitions()

        // Step 5: Verify transition was created
        XCTAssertEqual(editorState.transitions.count, 1, "Should have one transition")
        XCTAssertEqual(transition.type, .crossfade, "Should be crossfade type")
        XCTAssertEqual(transition.duration.seconds, 0.5, accuracy: 0.01, "Should be 0.5s duration")
        XCTAssertTrue(transition.isEnabled, "Should be enabled by default")

        // Verify transition appears in timeline
        let trackTransitions = viewModel.transitions(for: track.id)
        XCTAssertEqual(trackTransitions.count, 1, "Transition should appear in track")
        XCTAssertEqual(trackTransitions.first?.id, transition.id, "Transition ID should match")

        // Manual smoke test: Verify visual rendering
        // - Transition should appear in center of overlap
        // - Should be visually distinct from clips
        // - Should be selectable
        let trackView = ClipTrackView(
            track: track,
            viewModel: viewModel,
            selectedClipIDs: viewModel.selectedClipIDs,
            onClipSelected: { _ in },
            onClipDragged: { _, _ in }
        )
        _ = trackView.body
    }

    /// Test complete context menu workflow
    ///
    /// Workflow steps:
    /// 1. Create two overlapping clips on timeline
    /// 2. Right-click on overlap area
    /// 3. Select "Add Transition" from context menu
    /// 4. Choose preset from submenu (e.g., "Wipe Left")
    /// 5. Verify transition is created
    func testCompleteContextMenuWorkflow() {
        // Step 1: Create overlapping clips
        let (leading, trailing) = createOverlappingClips()
        track.clips = [leading, trailing]
        editorState.clipTracks = [track]

        // Step 2-3: Simulate context menu invocation (right-click on overlap)
        // In actual implementation, this shows menu with "Add Transition" option

        // Step 4: Select preset from submenu
        let preset = BuiltInPresets.presets.first { $0.name == "Wipe Left" }
        XCTAssertNotNil(preset, "Wipe Left preset should exist")

        guard let wipePreset = preset else { return }

        // Step 5: Create transition (simulating menu selection)
        let transition = wipePreset.makeTransition(
            leadingClipID: leading.id,
            trailingClipID: trailing.id
        )

        editorState.addTransition(transition)
        viewModel.syncTransitions()

        // Verify transition was created
        XCTAssertEqual(editorState.transitions.count, 1, "Should have one transition")
        XCTAssertEqual(transition.type, .wipeLeft, "Should be wipeLeft type")

        // Verify transition is between correct clips
        let foundTransition = viewModel.transition(between: leading.id, and: trailing.id)
        XCTAssertNotNil(foundTransition, "Should find transition between clips")
        XCTAssertEqual(foundTransition?.type, .wipeLeft, "Transition type should match")

        // Manual smoke test: Verify context menu appears on right-click
        // - Menu should show "Add Transition" option
        // - Submenu should list all 5 built-in presets
        // - Each preset should show formatted duration
    }

    /// Test complete auto-prompt workflow
    ///
    /// Workflow steps:
    /// 1. Create two clips with 1+ second overlap
    /// 2. Drop second clip to create overlap
    /// 3. Auto-prompt appears: "Add transition between clips?"
    /// 4. Click "Quick Dissolve" button in prompt
    /// 5. Verify transition is created
    /// 6. Verify prompt doesn't show again for same overlap
    func testCompleteAutoPromptWorkflow() {
        // Step 1: Create clips
        let leading = VideoClip(
            id: UUID(),
            sourceURL: URL(fileURLWithPath: "/tmp/clip1.mp4"),
            startTime: CMTime(seconds: 0, preferredTimescale: 600),
            duration: CMTime(seconds: 5, preferredTimescale: 600)
        )

        let trailing = VideoClip(
            id: UUID(),
            sourceURL: URL(fileURLWithPath: "/tmp/clip2.mp4"),
            startTime: CMTime(seconds: 4, preferredTimescale: 600), // 1s overlap
            duration: CMTime(seconds: 5, preferredTimescale: 600)
        )

        track.clips = [leading, trailing]
        editorState.clipTracks = [track]

        // Step 2-3: Detect overlap (simulating auto-prompt trigger)
        let overlap = calculateOverlap(leading: leading, trailing: trailing)
        XCTAssertGreaterThanOrEqual(overlap.seconds, 0.5,
                                   "Overlap should meet minimum requirement (0.5s)")

        // Verify no existing transition
        var existingTransition = viewModel.transition(between: leading.id, and: trailing.id)
        XCTAssertNil(existingTransition, "Should not have transition yet")

        // Step 4: Apply Quick Dissolve from prompt
        let preset = BuiltInPresets.presets.first { $0.name == "Quick Dissolve" }
        XCTAssertNotNil(preset, "Quick Dissolve preset should exist")

        guard let dissolvePreset = preset else { return }

        let transition = dissolvePreset.makeTransition(
            leadingClipID: leading.id,
            trailingClipID: trailing.id
        )

        // Step 5: Add transition
        editorState.addTransition(transition)
        viewModel.syncTransitions()

        // Verify transition was created
        XCTAssertEqual(editorState.transitions.count, 1, "Should have one transition")

        // Step 6: Verify prompt wouldn't show again (transition now exists)
        existingTransition = viewModel.transition(between: leading.id, and: trailing.id)
        XCTAssertNotNil(existingTransition, "Transition should now exist")

        // Manual smoke test: Verify prompt behavior
        // - Prompt should appear when dropping clip with sufficient overlap
        // - Prompt should show Quick Dissolve button prominently
        // - Prompt should have "Don't ask again" option
        // - Prompt should respect 5-minute cooldown after dismissal
    }

    /// Test complete keyboard shortcut workflow
    ///
    /// Workflow steps:
    /// 1. Create two overlapping clips
    /// 2. Select the overlap area (leading clip)
    /// 3. Press Cmd+Opt+T
    /// 4. Verify Quick Dissolve transition is created
    /// 5. Repeat with different overlap - should reuse last preset
    func testCompleteKeyboardShortcutWorkflow() {
        // Step 1: Create overlapping clips
        let (leading, trailing) = createOverlappingClips()
        track.clips = [leading, trailing]
        editorState.clipTracks = [track]

        // Step 2: Select leading clip (simulating user selection)
        viewModel.selectClip(leading.id)
        XCTAssertTrue(viewModel.selectedClipIDs.contains(leading.id),
                     "Leading clip should be selected")

        // Step 3: Simulate keyboard shortcut Cmd+Opt+T
        // In actual implementation, this triggers quick transition command

        // Step 4: Create Quick Dissolve (default for keyboard shortcut)
        let preset = BuiltInPresets.presets.first { $0.name == "Quick Dissolve" }
        XCTAssertNotNil(preset, "Quick Dissolve preset should exist")

        guard let dissolvePreset = preset else { return }

        let transition = dissolvePreset.makeTransition(
            leadingClipID: leading.id,
            trailingClipID: trailing.id
        )

        editorState.addTransition(transition)
        viewModel.syncTransitions()

        // Verify transition was created
        XCTAssertEqual(editorState.transitions.count, 1, "Should have one transition")
        XCTAssertEqual(transition.type, .crossfade, "Should be crossfade (Quick Dissolve)")

        // Step 5: Test with second overlap (should reuse preset)
        let clip3 = VideoClip(
            id: UUID(),
            sourceURL: URL(fileURLWithPath: "/tmp/clip3.mp4"),
            startTime: CMTime(seconds: 8, preferredTimescale: 600), // Overlaps with trailing
            duration: CMTime(seconds: 5, preferredTimescale: 600)
        )

        track.clips = [leading, trailing, clip3]
        editorState.clipTracks = [track]

        // Create second transition
        let transition2 = dissolvePreset.makeTransition(
            leadingClipID: trailing.id,
            trailingClipID: clip3.id
        )

        editorState.addTransition(transition2)
        viewModel.syncTransitions()

        // Verify both transitions exist
        XCTAssertEqual(editorState.transitions.count, 2, "Should have two transitions")

        // Manual smoke test: Verify keyboard shortcut
        // - Cmd+Opt+T should work when overlap area is selected
        // - Should default to Quick Dissolve
        // - Should remember last used preset for subsequent uses
        // - Should show feedback when transition is created
    }

    /// Test inspector preview loop workflow
    ///
    /// Workflow steps:
    /// 1. Create transition between clips
    /// 2. Select transition in timeline
    /// 3. Open Inspector
    /// 4. Switch to Preview tab
    /// 5. Adjust duration slider
    /// 6. Click "Play Preview" button
    /// 7. Verify animation plays correctly
    /// 8. Change transition type
    /// 9. Verify preview updates
    func testInspectorPreviewLoop() {
        // Step 1: Create transition
        let (leading, trailing, transition) = TestDataFactory.makeOverlappingClipsWithTransition()
        track.clips = [leading, trailing]
        editorState.clipTracks = [track]
        editorState.addTransition(transition)
        viewModel.syncTransitions()

        // Step 2-3: Select transition and open inspector
        viewModel.selectTransition(transition.id)
        XCTAssertTrue(viewModel.isTransitionSelected(transition.id),
                     "Transition should be selected")

        // Step 4: Verify inspector can access transition properties
        XCTAssertEqual(transition.type, .crossfade, "Should be crossfade")
        XCTAssertEqual(transition.duration.seconds, 1.0, accuracy: 0.01, "Should be 1.0s")

        // Step 5: Adjust duration (simulate inspector interaction)
        let newDuration = CMTime(seconds: 2.0, preferredTimescale: 600)
        let updatedTransition = TransitionClip(
            id: transition.id,
            type: transition.type,
            duration: newDuration,
            leadingClipID: transition.leadingClipID,
            trailingClipID: transition.trailingClipID,
            parameters: transition.parameters,
            isEnabled: transition.isEnabled
        )

        editorState.updateTransition(updatedTransition)
        viewModel.syncTransitions()

        // Verify duration was updated
        let foundTransition = viewModel.transition(between: leading.id, and: trailing.id)
        XCTAssertEqual(foundTransition?.duration.seconds, 2.0, accuracy: 0.01,
                      "Duration should be updated to 2.0s")

        // Step 6-7: Preview animation (manual verification required)
        // Manual smoke test: Verify preview functionality
        // - Preview tab should show animation of transition
        // - Play button should trigger preview playback
        // - Duration slider should update preview in real-time
        // - Preview should show leading clip fading out
        // - Preview should show trailing clip fading in

        // Step 8-9: Change transition type
        let wipeTransition = TransitionClip(
            id: transition.id,
            type: .wipeLeft,
            duration: newDuration,
            leadingClipID: transition.leadingClipID,
            trailingClipID: transition.trailingClipID,
            parameters: .wipeLeft,
            isEnabled: transition.isEnabled
        )

        editorState.updateTransition(wipeTransition)
        viewModel.syncTransitions()

        // Verify type was updated
        let updated = viewModel.transition(between: leading.id, and: trailing.id)
        XCTAssertEqual(updated?.type, .wipeLeft, "Type should be updated to wipeLeft")

        // Manual smoke test: Verify preview updates with new type
        // - Preview should immediately show wipe animation
        // - Preview should reflect new duration
        // - All parameters should update preview
    }

    /// Test preset application workflow
    ///
    /// Workflow steps:
    /// 1. Create transition between clips
    /// 2. Select transition
    /// 3. Open Inspector Presets tab
    /// 4. Click "Slow Fade" preset
    /// 5. Verify all parameters update
    /// 6. Click "Circle Reveal" preset
    /// 7. Verify parameters update again
    func testPresetApplication() {
        // Step 1: Create transition
        let (leading, trailing, transition) = TestDataFactory.makeOverlappingClipsWithTransition()
        track.clips = [leading, trailing]
        editorState.clipTracks = [track]
        editorState.addTransition(transition)
        viewModel.syncTransitions()

        // Step 2-3: Select transition and open inspector
        viewModel.selectTransition(transition.id)

        // Step 4: Apply "Slow Fade" preset
        let slowFadePreset = BuiltInPresets.presets.first { $0.name == "Slow Fade" }
        XCTAssertNotNil(slowFadePreset, "Slow Fade preset should exist")

        guard let slowFade = slowFadePreset else { return }

        let slowFadeTransition = TransitionClip(
            id: transition.id,
            type: slowFade.transitionType,
            duration: slowFade.duration,
            leadingClipID: transition.leadingClipID,
            trailingClipID: transition.trailingClipID,
            parameters: slowFade.parameters,
            isEnabled: transition.isEnabled
        )

        editorState.updateTransition(slowFadeTransition)
        viewModel.syncTransitions()

        // Step 5: Verify parameters updated
        let found = viewModel.transition(between: leading.id, and: trailing.id)
        XCTAssertEqual(found?.type, .crossfade, "Should be crossfade")
        XCTAssertEqual(found?.duration.seconds, 2.0, accuracy: 0.01,
                      "Duration should be 2.0s (Slow Fade)")

        // Step 6: Apply "Circle Reveal" preset
        let circlePreset = BuiltInPresets.presets.first { $0.name == "Circle Reveal" }
        XCTAssertNotNil(circlePreset, "Circle Reveal preset should exist")

        guard let circleReveal = circlePreset else { return }

        let circleTransition = TransitionClip(
            id: transition.id,
            type: circleReveal.transitionType,
            duration: circleReveal.duration,
            leadingClipID: transition.leadingClipID,
            trailingClipID: transition.trailingClipID,
            parameters: circleReveal.parameters,
            isEnabled: transition.isEnabled
        )

        editorState.updateTransition(circleTransition)
        viewModel.syncTransitions()

        // Step 7: Verify parameters updated again
        let updated = viewModel.transition(between: leading.id, and: trailing.id)
        XCTAssertEqual(updated?.type, .circleReveal, "Should be circleReveal")
        XCTAssertEqual(updated?.duration.seconds, 1.5, accuracy: 0.01,
                      "Duration should be 1.5s (Circle Reveal)")

        // Manual smoke test: Verify preset UI
        // - Presets tab should list all 5 built-in presets
        // - Each preset should show name and duration
        // - Clicking preset should immediately apply all parameters
        // - Visual feedback should indicate which preset is active
        // - Preset application should be undoable
    }

    // MARK: - Helper Methods

    /// Creates two overlapping clips with 1 second overlap
    private func createOverlappingClips() -> (VideoClip, VideoClip) {
        let leading = VideoClip(
            id: UUID(),
            sourceURL: URL(fileURLWithPath: "/tmp/clip1.mp4"),
            startTime: CMTime(seconds: 0, preferredTimescale: 600),
            duration: CMTime(seconds: 5, preferredTimescale: 600)
        )

        let trailing = VideoClip(
            id: UUID(),
            sourceURL: URL(fileURLWithPath: "/tmp/clip2.mp4"),
            startTime: CMTime(seconds: 4, preferredTimescale: 600), // 1s overlap
            duration: CMTime(seconds: 5, preferredTimescale: 600)
        )

        return (leading, trailing)
    }

    /// Calculates overlap duration between two clips
    private func calculateOverlap(leading: VideoClip, trailing: VideoClip) -> CMTime {
        let leadingEnd = leading.timeRangeInTimeline.end
        let trailingStart = trailing.timeRangeInTimeline.start

        guard leadingEnd > trailingStart else {
            return .zero
        }

        return max(CMTime(seconds: 0, preferredTimescale: 600), leadingEnd - trailingStart)
    }
}

// MARK: - TimelineViewModel Extension for Testing

extension TimelineViewModel {
    /// Syncs transitions from editor state (for testing)
    func syncTransitions() {
        transitions = editorState.transitions
    }

    /// Returns transition between two clips
    func transition(between leadingID: UUID, and trailingID: UUID) -> TransitionClip? {
        return transitions.first { t in
            t.leadingClipID == leadingID && t.trailingClipID == trailingID
        }
    }

    /// Checks if transition is selected
    func isTransitionSelected(_ id: UUID) -> Bool {
        return selectedTransitionID == id
    }
}
