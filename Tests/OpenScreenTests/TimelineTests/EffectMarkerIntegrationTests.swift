import XCTest
@testable import OpenScreen

@MainActor
final class EffectMarkerIntegrationTests: XCTestCase {

    var timelineView: TimelineView!
    var editorState: EditorState!
    var testDuration: CMTime!

    override func setUp() {
        super.setUp()

        // Create test duration
        testDuration = CMTime(seconds: 10.0, preferredTimescale: 600)

        // Create test editor state
        editorState = EditorState.createTestState()
        editorState.duration = testDuration

        // Create timeline view
        let frame = NSRect(x: 0, y: 0, width: 800, height: 200)
        timelineView = TimelineView(frame: frame, device: nil)

        // Configure timeline with editor state
        timelineView.configure(with: editorState)
    }

    override func tearDown() {
        timelineView = nil
        editorState = nil
        testDuration = nil
        super.tearDown()
    }

    // MARK: - Test 1: Effect Marker Notification Sync

    func testEffectMarkerNotificationSync() {
        // Create a test effect
        let effect = VideoEffect(
            type: .brightness,
            parameters: .brightness(0.5),
            timeRange: CMTime(seconds: 2.0, preferredTimescale: 600)...
                CMTime(seconds: 5.0, preferredTimescale: 600)
        )

        // Initially, effect marker track view should be empty
        guard let effectMarkerTrackView = timelineView.effectMarkerTrackView else {
            XCTFail("EffectMarkerTrackView should be created")
            return
        }

        XCTAssertEqual(effectMarkerTrackView.effectMarkers.count, 0, "Should have no effect markers initially")

        // Add effect to editor state (this should trigger notification)
        editorState.effectStack.videoEffects.append(effect)

        // Force update to ensure sync
        timelineView.updateEffectMarkers()

        // Verify effect marker was added
        XCTAssertEqual(effectMarkerTrackView.effectMarkers.count, 1, "Should have one effect marker")
        XCTAssertEqual(effectMarkerTrackView.effectMarkers.first?.id, effect.id, "Effect marker should match")
    }

    // MARK: - Test 2: Effect Stack Changes

    func testEffectStackChanges() {
        // Create multiple effects
        let effect1 = VideoEffect(
            type: .brightness,
            parameters: .brightness(0.5),
            timeRange: CMTime(seconds: 1.0, preferredTimescale: 600)...
                CMTime(seconds: 3.0, preferredTimescale: 600)
        )

        let effect2 = VideoEffect(
            type: .contrast,
            parameters: .contrast(1.2),
            timeRange: CMTime(seconds: 4.0, preferredTimescale: 600)...
                CMTime(seconds: 6.0, preferredTimescale: 600)
        )

        guard let effectMarkerTrackView = timelineView.effectMarkerTrackView else {
            XCTFail("EffectMarkerTrackView should be created")
            return
        }

        // Add effects one by one
        editorState.effectStack.videoEffects.append(effect1)
        timelineView.updateEffectMarkers()
        XCTAssertEqual(effectMarkerTrackView.effectMarkers.count, 1, "Should have one effect marker")

        editorState.effectStack.videoEffects.append(effect2)
        timelineView.updateEffectMarkers()
        XCTAssertEqual(effectMarkerTrackView.effectMarkers.count, 2, "Should have two effect markers")

        // Remove an effect
        editorState.effectStack.videoEffects.removeAll { $0.id == effect1.id }
        timelineView.updateEffectMarkers()
        XCTAssertEqual(effectMarkerTrackView.effectMarkers.count, 1, "Should have one effect marker after removal")

        // Clear all effects
        editorState.effectStack.videoEffects.removeAll()
        timelineView.updateEffectMarkers()
        XCTAssertEqual(effectMarkerTrackView.effectMarkers.count, 0, "Should have no effect markers after clearing")
    }

    // MARK: - Test 3: Timeline View Configuration

    func testTimelineViewConfiguration() {
        // Create effects with different time ranges
        let effects: [VideoEffect] = [
            VideoEffect(
                type: .brightness,
                parameters: .brightness(0.5),
                timeRange: CMTime(seconds: 1.0, preferredTimescale: 600)...
                    CMTime(seconds: 2.0, preferredTimescale: 600)
            ),
            VideoEffect(
                type: .contrast,
                parameters: .contrast(1.2),
                timeRange: CMTime(seconds: 3.0, preferredTimescale: 600)...
                    CMTime(seconds: 5.0, preferredTimescale: 600)
            ),
            VideoEffect(
                type: .saturation,
                parameters: .saturation(1.1),
                timeRange: CMTime(seconds: 6.0, preferredTimescale: 600)...
                    CMTime(seconds: 8.0, preferredTimescale: 600)
            )
        ]

        // Set up editor state with effects
        editorState.effectStack.videoEffects = effects

        // Configure timeline view
        timelineView.configure(with: editorState)

        // Verify effect marker track view is set up
        guard let effectMarkerTrackView = timelineView.effectMarkerTrackView else {
            XCTFail("EffectMarkerTrackView should be created")
            return
        }

        // Verify all properties are synced
        XCTAssertEqual(effectMarkerTrackView.videoDuration, testDuration, "Video duration should be synced")
        XCTAssertEqual(effectMarkerTrackView.contentScale, 1.0, "Content scale should be synced")
        XCTAssertEqual(effectMarkerTrackView.contentOffset, CGPoint.zero, "Content offset should be synced")
        XCTAssertEqual(effectMarkerTrackView.visibleTimeRange, CMTime.zero...testDuration, "Visible time range should be synced")

        // Verify effects are added
        XCTAssertEqual(effectMarkerTrackView.effectMarkers.count, 3, "Should have three effect markers")
    }

    // MARK: - Test 4: Effect Duration Edge Cases

    func testEffectDurationEdgeCases() {
        // Test effects with very short durations
        let shortEffect = VideoEffect(
            type: .brightness,
            parameters: .brightness(0.5),
            timeRange: CMTime(seconds: 2.0, preferredTimescale: 600)...
                CMTime(seconds: 2.1, preferredTimescale: 600) // 0.1 seconds
        )

        // Test effects with longer durations
        let longEffect = VideoEffect(
            type: .contrast,
            parameters: .contrast(1.2),
            timeRange: CMTime(seconds: 3.0, preferredTimescale: 600)...
                CMTime(seconds: 9.0, preferredTimescale: 600) // 6 seconds
        )

        // Add effects to editor state
        editorState.effectStack.videoEffects = [shortEffect, longEffect]

        // Force update effect markers
        timelineView.updateEffectMarkers()

        // Verify effects are added
        guard let effectMarkerTrackView = timelineView.effectMarkerTrackView else {
            XCTFail("EffectMarkerTrackView should be created")
            return
        }

        XCTAssertEqual(effectMarkerTrackView.effectMarkers.count, 2, "Should have two effect markers")

        // Verify effects have valid time ranges
        for effect in effectMarkerTrackView.effectMarkers {
            XCTAssertNotNil(effect.timeRange, "All effects should have time ranges")
            let lower = CMTimeGetSeconds(effect.timeRange!.lowerBound)
            let upper = CMTimeGetSeconds(effect.timeRange!.upperBound)
            XCTAssertLessThan(lower, upper, "Start time should be less than end time")
            XCTAssertGreaterThanOrEqual(lower, 0.0, "Start time should not be negative")
        }

        // Test with zero duration (should be handled gracefully)
        let zeroDurationEffect = VideoEffect(
            type: .saturation,
            parameters: .saturation(1.1),
            timeRange: CMTime(seconds: 5.0, preferredTimescale: 600)...
                CMTime(seconds: 5.0, preferredTimescale: 600) // Zero duration
        )

        editorState.effectStack.videoEffects.append(zeroDurationEffect)
        timelineView.updateEffectMarkers()

        // Should still have all effects (zero duration effects are still tracked)
        XCTAssertEqual(effectMarkerTrackView.effectMarkers.count, 3, "Should have three effect markers including zero duration")
    }
}