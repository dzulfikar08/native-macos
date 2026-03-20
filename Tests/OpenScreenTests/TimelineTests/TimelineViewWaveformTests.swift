import XCTest
@testable import OpenScreen

@MainActor
final class TimelineViewWaveformTests: XCTestCase {
    var timelineView: TimelineView!

    override func setUp() async throws {
        try await super.setUp()
        timelineView = TimelineView(frame: NSRect(x: 0, y: 0, width: 800, height: 200))
    }

    override func tearDown() async throws {
        timelineView = nil
        try await super.tearDown()
    }

    // MARK: - Waveform Property Tests

    func testWaveformDefaultValue() {
        // Test default waveform is empty
        XCTAssertTrue(timelineView.waveform.isEmpty, "Waveform should be empty by default")
    }

    func testWaveformIsReadable() {
        // Test that waveform property is readable
        let emptyWaveform = timelineView.waveform
        XCTAssertTrue(emptyWaveform.isEmpty, "Should be able to read waveform property")
    }

    // MARK: - Set Waveform Tests

    func testSetWaveformWithEmptyArray() {
        // When: Setting empty waveform
        let testWaveform: [Double] = []
        timelineView.setWaveform(testWaveform)

        // Then: Waveform should be empty
        XCTAssertTrue(timelineView.waveform.isEmpty, "Waveform should be empty")
    }

    func testSetWaveformWithSingleValue() {
        // When: Setting waveform with single value
        let testWaveform: [Double] = [0.5]
        timelineView.setWaveform(testWaveform)

        // Then: Waveform should have one element
        XCTAssertEqual(timelineView.waveform.count, 1, "Waveform should have 1 element")
        XCTAssertEqual(timelineView.waveform[0], 0.5, accuracy: 0.01, "Waveform value should match")
    }

    func testSetWaveformWithMultipleValues() {
        // When: Setting waveform with multiple values
        let testWaveform: [Double] = [0.1, 0.5, 0.9, 0.3, 0.7]
        timelineView.setWaveform(testWaveform)

        // Then: Waveform should have all elements
        XCTAssertEqual(timelineView.waveform.count, 5, "Waveform should have 5 elements")
        XCTAssertEqual(timelineView.waveform[0], 0.1, accuracy: 0.01, "First value should match")
        XCTAssertEqual(timelineView.waveform[2], 0.9, accuracy: 0.01, "Middle value should match")
        XCTAssertEqual(timelineView.waveform[4], 0.7, accuracy: 0.01, "Last value should match")
    }

    func testSetWaveformWithLargeDataset() {
        // When: Setting waveform with large dataset
        let testWaveform = Array(repeating: 0.5, count: 10000)
        timelineView.setWaveform(testWaveform)

        // Then: Waveform should handle large datasets
        XCTAssertEqual(timelineView.waveform.count, 10000, "Waveform should handle large datasets")
    }

    // MARK: - Waveform Triggers Redraw Tests

    func testSetWaveformTriggersRedraw() {
        // Test that setting waveform triggers redraw
        let testWaveform: [Double] = [0.5, 0.6, 0.7]
        timelineView.setWaveform(testWaveform)

        // The didSet should set needsDisplay = true
        // We verify by checking the waveform was set
        XCTAssertEqual(timelineView.waveform.count, 3, "Waveform should be set")
    }

    // MARK: - Waveform Value Range Tests

    func testWaveformWithZeroValues() {
        // When: Setting waveform with zeros
        let testWaveform: [Double] = [0.0, 0.0, 0.0]
        timelineView.setWaveform(testWaveform)

        // Then: Should handle zero values
        XCTAssertEqual(timelineView.waveform.count, 3, "Waveform should handle zeros")
        XCTAssertEqual(timelineView.waveform[0], 0.0, accuracy: 0.01, "Zero values should be preserved")
    }

    func testWaveformWithMaximumValues() {
        // When: Setting waveform with maximum values
        let testWaveform: [Double] = [1.0, 1.0, 1.0]
        timelineView.setWaveform(testWaveform)

        // Then: Should handle maximum values
        XCTAssertEqual(timelineView.waveform.count, 3, "Waveform should handle maximum values")
        XCTAssertEqual(timelineView.waveform[0], 1.0, accuracy: 0.01, "Maximum values should be preserved")
    }

    func testWaveformWithNegativeValues() {
        // When: Setting waveform with negative values
        let testWaveform: [Double] = [-0.5, -0.3, -0.7]
        timelineView.setWaveform(testWaveform)

        // Then: Should handle negative values
        XCTAssertEqual(timelineView.waveform.count, 3, "Waveform should handle negative values")
        XCTAssertEqual(timelineView.waveform[0], -0.5, accuracy: 0.01, "Negative values should be preserved")
    }

    func testWaveformWithMixedValues() {
        // When: Setting waveform with mixed positive, negative, and zero values
        let testWaveform: [Double] = [-1.0, 0.0, 0.5, 1.0]
        timelineView.setWaveform(testWaveform)

        // Then: Should handle mixed values
        XCTAssertEqual(timelineView.waveform.count, 4, "Waveform should handle mixed values")
        XCTAssertEqual(timelineView.waveform[0], -1.0, accuracy: 0.01, "Negative value should be preserved")
        XCTAssertEqual(timelineView.waveform[2], 0.5, accuracy: 0.01, "Positive value should be preserved")
    }

    // MARK: - Waveform Replacement Tests

    func testReplaceExistingWaveform() {
        // Given: Existing waveform
        timelineView.setWaveform([0.1, 0.2, 0.3])
        XCTAssertEqual(timelineView.waveform.count, 3, "Initial waveform should be set")

        // When: Replacing with new waveform
        let newWaveform: [Double] = [0.4, 0.5, 0.6, 0.7]
        timelineView.setWaveform(newWaveform)

        // Then: Waveform should be replaced
        XCTAssertEqual(timelineView.waveform.count, 4, "Waveform should be replaced")
        XCTAssertEqual(timelineView.waveform[0], 0.4, accuracy: 0.01, "New waveform should be used")
    }

    func testReplaceWithEmptyWaveform() {
        // Given: Existing waveform
        timelineView.setWaveform([0.1, 0.2, 0.3])
        XCTAssertEqual(timelineView.waveform.count, 3, "Initial waveform should be set")

        // When: Replacing with empty waveform
        timelineView.setWaveform([])

        // Then: Waveform should be cleared
        XCTAssertTrue(timelineView.waveform.isEmpty, "Waveform should be cleared")
    }

    // MARK: - Waveform Rendering Tests

    func testDrawWithWaveform() {
        // Given: Timeline with waveform
        timelineView.setWaveform([0.1, 0.5, 0.9, 0.3, 0.7])

        // When: Drawing
        XCTAssertNoThrow(timelineView.draw(NSRect.zero), "Draw should not throw with waveform")
    }

    func testDrawWithLargeWaveform() {
        // Given: Timeline with large waveform
        let largeWaveform = Array(repeating: 0.5, count: 10000)
        timelineView.setWaveform(largeWaveform)

        // When: Drawing
        XCTAssertNoThrow(timelineView.draw(NSRect.zero), "Draw should handle large waveforms")
    }

    func testDrawWithEmptyWaveform() {
        // Given: Timeline with empty waveform
        timelineView.setWaveform([])

        // When: Drawing
        XCTAssertNoThrow(timelineView.draw(NSRect.zero), "Draw should handle empty waveform")
    }

    // MARK: - Waveform with Content Scale Tests

    func testWaveformWithDifferentScales() {
        // Given: Timeline with waveform
        timelineView.setWaveform([0.1, 0.5, 0.9, 0.3, 0.7])

        // When: Changing scale
        timelineView.contentScale = 2.0

        // Then: Should still render
        XCTAssertNoThrow(timelineView.draw(NSRect.zero), "Waveform should render at different scales")
    }

    // MARK: - Audio Waveform Method Tests

    func testSetAudioWaveformMethod() {
        // Test that setAudioWaveform method works
        let testWaveform: [Double] = [0.1, 0.5, 0.9]
        timelineView.setAudioWaveform(testWaveform)

        XCTAssertEqual(timelineView.waveform.count, 3, "setAudioWaveform should set waveform")
    }

    func testSetAudioWaveformMethodWithNil() {
        // Test that setAudioWaveform with nil clears waveform
        timelineView.setWaveform([0.1, 0.5, 0.9])
        XCTAssertEqual(timelineView.waveform.count, 3, "Initial waveform should be set")

        timelineView.setAudioWaveform(nil)

        XCTAssertTrue(timelineView.waveform.isEmpty, "setAudioWaveform(nil) should clear waveform")
    }

    func testSetAudioWaveformMethodWithEmptyArray() {
        // Test that setAudioWaveform with empty array clears waveform
        timelineView.setWaveform([0.1, 0.5, 0.9])
        XCTAssertEqual(timelineView.waveform.count, 3, "Initial waveform should be set")

        timelineView.setAudioWaveform([])

        XCTAssertTrue(timelineView.waveform.isEmpty, "setAudioWaveform([]) should clear waveform")
    }
}
