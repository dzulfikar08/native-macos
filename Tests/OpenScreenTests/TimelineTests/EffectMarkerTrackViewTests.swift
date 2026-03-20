import XCTest
@testable import OpenScreen

@MainActor
final class EffectMarkerTrackViewTests: XCTestCase {

    var effectMarkerTrackView: EffectMarkerTrackView!
    var testDuration: CMTime!

    override func setUp() {
        super.setUp()

        // Create test duration
        testDuration = CMTime(seconds: 10.0, preferredTimescale: 600)

        // Create effect marker track view
        let frame = NSRect(x: 0, y: 0, width: 800, height: 200)
        effectMarkerTrackView = EffectMarkerTrackView(frame: frame)

        // Configure basic properties
        effectMarkerTrackView.videoDuration = testDuration
        effectMarkerTrackView.contentScale = 100.0 // 100 pixels per second
        effectMarkerTrackView.contentOffset = CGPoint(x: 0, y: 0)
        effectMarkerTrackView.visibleTimeRange = CMTime.zero...testDuration
    }

    override func tearDown() {
        effectMarkerTrackView = nil
        testDuration = nil
        super.tearDown()
    }

    // MARK: - Test 1: Time Conversion Methods

    func testTimeToXPositionConversion() {
        // Test conversion from time to x position
        let time: Double = 2.5
        let expectedX = CGFloat(time) * effectMarkerTrackView.contentScale // 2.5 * 100 = 250
        let actualX = effectMarkerTrackView.timeToXPosition(time)

        XCTAssertEqual(actualX, expectedX, "Time to x position conversion should be accurate")
    }

    func testXPositionToTimeConversion() {
        // Test conversion from x position to time
        let x: CGFloat = 300.0
        let expectedTime = Double(x) / effectMarkerTrackView.contentScale // 300 / 100 = 3.0
        let actualTime = effectMarkerTrackView.xPositionToTime(x)

        XCTAssertEqual(actualTime, expectedTime, "X position to time conversion should be accurate")
    }

    // MARK: - Test 2: Effect Marker Management

    func testAddAndClearEffectMarkers() {
        // Initially should have no markers
        XCTAssertEqual(effectMarkerTrackView.effectMarkers.count, 0, "Should have no effect markers initially")

        // Create test effect
        let effect = VideoEffect(
            type: .brightness,
            parameters: .brightness(0.5),
            timeRange: CMTime(seconds: 2.0, preferredTimescale: 600)...
                CMTime(seconds: 5.0, preferredTimescale: 600)
        )

        // Add effect marker
        effectMarkerTrackView.addEffectMarker(effect)

        // Verify marker was added
        XCTAssertEqual(effectMarkerTrackView.effectMarkers.count, 1, "Should have one effect marker")
        XCTAssertEqual(effectMarkerTrackView.effectMarkers.first?.id, effect.id, "Effect marker should match")

        // Clear all markers
        effectMarkerTrackView.clearEffectMarkers()

        // Verify all markers are cleared
        XCTAssertEqual(effectMarkerTrackView.effectMarkers.count, 0, "Should have no effect markers after clearing")
    }

    // MARK: - Test 3: Effect Marker Filtering

    func testEffectMarkerFiltering() {
        // Create multiple effects with different time ranges
        let effect1 = VideoEffect(
            type: .brightness,
            parameters: .brightness(0.5),
            timeRange: CMTime(seconds: 1.0, preferredTimescale: 600)...
                CMTime(seconds: 3.0, preferredTimescale: 600)
        )

        let effect2 = VideoEffect(
            type: .contrast,
            parameters: .contrast(1.2),
            timeRange: CMTime(seconds: 5.0, preferredTimescale: 600)...
                CMTime(seconds: 8.0, preferredTimescale: 600)
        )

        // Add effects
        effectMarkerTrackView.addEffectMarker(effect1)
        effectMarkerTrackView.addEffectMarker(effect2)

        XCTAssertEqual(effectMarkerTrackView.effectMarkers.count, 2, "Should have two effect markers")

        // Add an effect without time range (should be filtered out)
        let effect3 = VideoEffect(
            type: .saturation,
            parameters: .saturation(1.1),
            timeRange: nil
        )

        effectMarkerTrackView.addEffectMarker(effect3)

        // Should still have only two effects (the one without time range is filtered)
        XCTAssertEqual(effectMarkerTrackView.effectMarkers.count, 2, "Should filter out effects without time ranges")
    }

    // MARK: - Test 4: Visible Range Filtering

    func testVisibleRangeFiltering() {
        // Set up a timeline that shows seconds 2-8
        effectMarkerTrackView.contentOffset = CGPoint(x: 200, y: 0) // 2 seconds * 100 pixels/second
        effectMarkerTrackView.contentScale = 100.0
        effectMarkerTrackView.visibleTimeRange = CMTime(seconds: 2.0, preferredTimescale: 600)...
            CMTime(seconds: 8.0, preferredTimescale: 600)

        // Create effects at different positions
        let effect1 = VideoEffect(
            type: .brightness,
            parameters: .brightness(0.5),
            timeRange: CMTime(seconds: 1.0, preferredTimescale: 600)... // Before visible range
                CMTime(seconds: 3.0, preferredTimescale: 600)
        )

        let effect2 = VideoEffect(
            type: .contrast,
            parameters: .contrast(1.2),
            timeRange: CMTime(seconds: 5.0, preferredTimescale: 600)... // Within visible range
                CMTime(seconds: 7.0, preferredTimescale: 600)
        )

        let effect3 = VideoEffect(
            type: .saturation,
            parameters: .saturation(1.1),
            timeRange: CMTime(seconds: 9.0, preferredTimescale: 600)... // After visible range
                CMTime(seconds: 10.0, preferredTimescale: 600)
        )

        // Add all effects
        effectMarkerTrackView.addEffectMarker(effect1)
        effectMarkerTrackView.addEffectMarker(effect2)
        effectMarkerTrackView.addEffectMarker(effect3)

        // Should have all effects (draw method filters out-of-bounds effects)
        XCTAssertEqual(effectMarkerTrackView.effectMarkers.count, 3, "Should have all three effect markers")

        // Test drawing with the given visible range
        // Note: Actual drawing test would require mocking the graphics context
        // This test mainly verifies the setup and marker existence
    }
}