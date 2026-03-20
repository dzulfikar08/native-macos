import XCTest
@testable import OpenScreen

@MainActor
final class EffectMarkerTests: XCTestCase {

    var timelineView: TimelineView!
    var editorState: EditorState!
    var testDuration: CMTime!

    override func setUp() {
        super.setUp()

        // Create test duration (10 seconds)
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

    // MARK: - Test 1: Basic Effect Marker Rendering

    func testEffectMarkerRendering() {
        // Create a test effect with time range
        let effect = VideoEffect(
            type: .brightness,
            parameters: .brightness(0.5),
            timeRange: CMTime(seconds: 2.0, preferredTimescale: 600)...
                CMTime(seconds: 6.0, preferredTimescale: 600)
        )

        // Add effect to editor state
        editorState.effectStack.videoEffects.append(effect)

        // Force update effect markers
        timelineView.updateEffectMarkers()

        // Verify effect marker was added to the track view
        guard let effectMarkerTrackView = timelineView.effectMarkerTrackView else {
            XCTFail("EffectMarkerTrackView should be created")
            return
        }

        // Check that the effect marker exists
        XCTAssertEqual(effectMarkerTrackView.effectMarkers.count, 1, "Should have one effect marker")
        XCTAssertEqual(effectMarkerTrackView.effectMarkers.first?.id, effect.id, "Effect marker should match")
    }

    // MARK: - Test 2: Multiple Overlapping Effects

    func testMultipleOverlappingEffects() {
        // Create multiple overlapping effects
        let effect1 = VideoEffect(
            type: .brightness,
            parameters: .brightness(0.5),
            timeRange: CMTime(seconds: 1.0, preferredTimescale: 600)...
                CMTime(seconds: 4.0, preferredTimescale: 600)
        )

        let effect2 = VideoEffect(
            type: .contrast,
            parameters: .contrast(1.2),
            timeRange: CMTime(seconds: 2.0, preferredTimescale: 600)...
                CMTime(seconds: 5.0, preferredTimescale: 600)
        )

        let effect3 = VideoEffect(
            type: .saturation,
            parameters: .saturation(1.1),
            timeRange: CMTime(seconds: 3.0, preferredTimescale: 600)...
                CMTime(seconds: 6.0, preferredTimescale: 600)
        )

        // Add effects to editor state
        editorState.effectStack.videoEffects = [effect1, effect2, effect3]

        // Force update effect markers
        timelineView.updateEffectMarkers()

        // Verify all effect markers were added
        guard let effectMarkerTrackView = timelineView.effectMarkerTrackView else {
            XCTFail("EffectMarkerTrackView should be created")
            return
        }

        XCTAssertEqual(effectMarkerTrackView.effectMarkers.count, 3, "Should have three effect markers")

        // Verify effects are sorted by start time
        let sortedEffects = effectMarkerTrackView.effectMarkers.sorted {
            $0.timeRange!.lowerBound < $1.timeRange!.lowerBound
        }

        XCTAssertEqual(sortedEffects[0].type, .brightness, "First effect should be brightness")
        XCTAssertEqual(sortedEffects[1].type, .contrast, "Second effect should be contrast")
        XCTAssertEqual(sortedEffects[2].type, .saturation, "Third effect should be saturation")
    }

    // MARK: - Test 3: Effect Labels and Boundaries

    func testEffectLabelsAndBoundaries() {
        // Create effects with different durations
        let shortEffect = VideoEffect(
            type: .brightness,
            parameters: .brightness(0.5),
            timeRange: CMTime(seconds: 1.0, preferredTimescale: 600)...
                CMTime(seconds: 2.0, preferredTimescale: 600) // 1 second duration
        )

        let longEffect = VideoEffect(
            type: .contrast,
            parameters: .contrast(1.2),
            timeRange: CMTime(seconds: 3.0, preferredTimescale: 600)...
                CMTime(seconds: 8.0, preferredTimescale: 600) // 5 second duration
        )

        // Add effects to editor state
        editorState.effectStack.videoEffects = [shortEffect, longEffect]

        // Force update effect markers
        timelineView.updateEffectMarkers()

        // Verify effects are added to track view
        guard let effectMarkerTrackView = timelineView.effectMarkerTrackView else {
            XCTFail("EffectMarkerTrackView should be created")
            return
        }

        XCTAssertEqual(effectMarkerTrackView.effectMarkers.count, 2, "Should have two effect markers")

        // Test time-to-position conversion
        let shortEffectStartX = effectMarkerTrackView.timeToXPosition(1.0)
        let shortEffectEndX = effectMarkerTrackView.timeToXPosition(2.0)
        let shortEffectWidth = shortEffectEndX - shortEffectStartX

        let longEffectStartX = effectMarkerTrackView.timeToXPosition(3.0)
        let longEffectEndX = effectMarkerTrackView.timeToXPosition(8.0)
        let longEffectWidth = longEffectEndX - longEffectStartX

        XCTAssertGreaterThan(shortEffectWidth, 0, "Short effect should have positive width")
        XCTAssertGreaterThan(longEffectWidth, shortEffectWidth, "Long effect should be wider than short effect")
    }

    // MARK: - Test 4: Effect Marker Selection and Moving

    func testEffectMarkerSelectionAndMoving() {
        // Create a test effect
        let effect = VideoEffect(
            type: .brightness,
            parameters: .brightness(0.5),
            timeRange: CMTime(seconds: 3.0, preferredTimescale: 600)...
                CMTime(seconds: 7.0, preferredTimescale: 600)
        )

        // Add effect to editor state
        editorState.effectStack.videoEffects.append(effect)

        // Force update effect markers
        timelineView.updateEffectMarkers()

        // Verify effect marker exists
        guard let effectMarkerTrackView = timelineView.effectMarkerTrackView else {
            XCTFail("EffectMarkerTrackView should be created")
            return
        }

        XCTAssertEqual(effectMarkerTrackView.effectMarkers.count, 1, "Should have one effect marker")

        // Test initial selection (should be nil)
        XCTAssertNil(effectMarkerTrackView.selectedEffect, "No effect should be selected initially")

        // Simulate mouse click on effect marker
        let effectStartX = effectMarkerTrackView.timeToXPosition(3.0)
        let effectEndX = effectMarkerTrackView.timeToXPosition(7.0)
        let clickX = (effectStartX + effectEndX) / 2 // Click in the middle
        let clickY = 100 // Arbitrary Y position in the view

        let clickEvent = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: NSPoint(x: clickX, y: clickY),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        )

        effectMarkerTrackView.mouseDown(with: clickEvent!)

        // Verify effect is selected
        XCTAssertEqual(effectMarkerTrackView.selectedEffect?.id, effect.id, "Effect should be selected")

        // Test moving effect
        let dragEvent = NSEvent.mouseEvent(
            with: .leftMouseDragged,
            location: NSPoint(x: clickX + 50, y: clickY), // Drag 50 pixels right
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        )

        effectMarkerTrackView.mouseDragged(with: dragEvent!)

        // Verify effect was moved (time range should be updated)
        let updatedEffect = effectMarkerTrackView.effectMarkers.first
        XCTAssertNotNil(updatedEffect, "Effect should still exist")

        if let updatedTimeRange = updatedEffect?.timeRange {
            let newStartTime = CMTimeGetSeconds(updatedTimeRange.lowerBound)
            let newEndTime = CMTimeGetSeconds(updatedTimeRange.upperBound)

            // Effect should have moved (approximately 50 pixels worth of time)
            XCTAssertNotEqual(newStartTime, 3.0, "Start time should have changed")
            XCTAssertNotEqual(newEndTime, 7.0, "End time should have changed")

            // Duration should remain the same
            let originalDuration = 4.0 // 7.0 - 3.0
            let newDuration = newEndTime - newStartTime
            XCTAssertEqual(newDuration, originalDuration, "Duration should remain unchanged")
        }

        // Test mouse up
        let mouseUpEvent = NSEvent.mouseEvent(
            with: .leftMouseUp,
            location: NSPoint(x: clickX + 50, y: clickY),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        )

        effectMarkerTrackView.mouseUp(with: mouseUpEvent!)
    }
}