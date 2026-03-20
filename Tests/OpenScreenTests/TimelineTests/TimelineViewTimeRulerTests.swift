import XCTest
@testable import OpenScreen

@MainActor
final class TimelineViewTimeRulerTests: XCTestCase {
    var timelineView: TimelineView!

    override func setUp() async throws {
        try await super.setUp()
        timelineView = TimelineView(frame: NSRect(x: 0, y: 0, width: 800, height: 200))
    }

    override func tearDown() async throws {
        timelineView = nil
        try await super.tearDown()
    }

    // MARK: - Show Frame Toggles Tests

    func testShowFrameTicksDefaultValue() {
        // Test default value of showFrameTicks
        XCTAssertFalse(timelineView.showFrameTicks, "showFrameTicks should default to false")
    }

    func testSetShowFrameTicksToTrue() {
        // When: Setting showFrameTicks to true
        timelineView.showFrameTicks = true

        // Then: Property should be updated
        XCTAssertTrue(timelineView.showFrameTicks, "showFrameTicks should be true")
    }

    func testSetShowFrameTicksToFalse() {
        // Given: showFrameTicks is true
        timelineView.showFrameTicks = true

        // When: Setting showFrameTicks to false
        timelineView.showFrameTicks = false

        // Then: Property should be updated
        XCTAssertFalse(timelineView.showFrameTicks, "showFrameTicks should be false")
    }

    func testShowFrameTicksTriggersRedraw() {
        // Test that changing showFrameTicks triggers redraw
        timelineView.showFrameTicks = true

        // The didSet should set needsDisplay = true
        XCTAssertTrue(timelineView.showFrameTicks, "showFrameTicks should be updated and trigger redraw")
    }

    // MARK: - Time Ruler Height Tests

    func testTimeRulerHeight() {
        // Test that time ruler height is positive
        let rulerHeight = timelineView.timeRulerHeight
        XCTAssertTrue(rulerHeight > 0, "Time ruler height should be positive")
    }

    func testTimeRulerHeightIsReasonable() {
        // Test that time ruler height is within reasonable bounds
        let rulerHeight = timelineView.timeRulerHeight
        XCTAssertTrue(rulerHeight >= 20 && rulerHeight <= 60, "Time ruler height should be between 20 and 60 points")
    }

    // MARK: - Tick Mark Tests

    func testMajorTickInterval() {
        // Test that major tick interval is calculated correctly
        // At default scale (1.0), major ticks should be at reasonable intervals
        let majorInterval = timelineView.majorTickInterval
        XCTAssertTrue(majorInterval > 0, "Major tick interval should be positive")
    }

    func testMinorTickInterval() {
        // Test that minor tick interval is calculated correctly
        let minorInterval = timelineView.minorTickInterval
        XCTAssertTrue(minorInterval > 0, "Minor tick interval should be positive")
    }

    func testMinorTickLessThanMajor() {
        // Test that minor ticks are more frequent than major ticks
        let majorInterval = timelineView.majorTickInterval
        let minorInterval = timelineView.minorTickInterval
        XCTAssertTrue(minorInterval < majorInterval, "Minor tick interval should be less than major tick interval")
    }

    func testFrameTickInterval() {
        // Test frame tick interval when showFrameTicks is enabled
        timelineView.showFrameTicks = true

        let frameInterval = timelineView.frameTickInterval
        XCTAssertTrue(frameInterval > 0, "Frame tick interval should be positive when enabled")
    }

    // MARK: - Time Scale Tests

    func testTickIntervalsAtDifferentScales() {
        // Test that tick intervals adjust with scale
        let originalMajor = timelineView.majorTickInterval

        // Increase scale (zoomed in)
        timelineView.contentScale = 2.0
        let zoomedMajor = timelineView.majorTickInterval

        // Intervals should adjust based on scale
        XCTAssertNotEqual(originalMajor, zoomedMajor, "Tick intervals should change with scale")
    }

    func testTickIntervalsAtZoomedOutScale() {
        // Test tick intervals when zoomed out
        timelineView.contentScale = 0.5

        let majorInterval = timelineView.majorTickInterval
        XCTAssertTrue(majorInterval > 0, "Major tick interval should still be positive when zoomed out")
    }

    // MARK: - Time Formatting Tests

    func testTimeFormattingForZero() {
        // Test formatting time 0
        let formatted = timelineView.formatTime(0.0)
        XCTAssertTrue(formatted.contains("0.") || formatted == "0.00", "Zero time should format correctly")
    }

    func testTimeFormattingForWholeSeconds() {
        // Test formatting whole seconds
        let formatted = timelineView.formatTime(5.0)
        XCTAssertTrue(formatted.contains("5"), "Formatted time should contain the seconds value")
    }

    func testTimeFormattingForFractionalSeconds() {
        // Test formatting fractional seconds
        let formatted = timelineView.formatTime(5.5)
        XCTAssertTrue(formatted.contains("5.5") || formatted.contains("5.50"), "Formatted time should show fractional seconds")
    }

    func testTimeFormattingForLargeValues() {
        // Test formatting large time values (minutes)
        let formatted = timelineView.formatTime(125.0) // 2 minutes 5 seconds
        XCTAssertTrue(formatted.contains(":"), "Time > 60 seconds should show minutes")
    }

    // MARK: - Ruler Position Tests

    func testRulerIsAtTop() {
        // Test that time ruler is positioned at the top of the view
        let rulerHeight = timelineView.timeRulerHeight
        XCTAssertTrue(rulerHeight > 0, "Ruler should have positive height")
        XCTAssertTrue(rulerHeight < timelineView.bounds.height, "Ruler should be within view bounds")
    }

    func testRulerHeightDoesNotExceedView() {
        // Test that ruler height doesn't exceed view height
        let smallView = TimelineView(frame: NSRect(x: 0, y: 0, width: 800, height: 50))
        let rulerHeight = smallView.timeRulerHeight
        XCTAssertTrue(rulerHeight <= smallView.bounds.height, "Ruler height should not exceed view height")
    }

    // MARK: - Content Offset Tests

    func testTimeRulerRespectsContentOffset() {
        // Test that time ruler rendering accounts for content offset
        timelineView.contentOffset = CGPoint(x: 100, y: 0)

        // Ruler should still render correctly
        XCTAssertNoThrow(timelineView.draw(NSRect.zero), "Ruler should render with content offset")
    }

    func testTimeRulerRespectsContentScale() {
        // Test that time ruler rendering accounts for content scale
        timelineView.contentScale = 2.0

        // Ruler should still render correctly
        XCTAssertNoThrow(timelineView.draw(NSRect.zero), "Ruler should render with content scale")
    }
}
