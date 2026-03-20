import XCTest
@testable import OpenScreen

@MainActor
final class ScrubControllerTests: XCTestCase {

    var scrubController: ScrubController!

    override func setUp() {
        super.setUp()
        // Initialize EditorState for testing
        EditorState.initializeShared(with: URL(fileURLWithPath: ""))
        scrubController = ScrubController()
    }

    override func tearDown() {
        scrubController = nil
        super.tearDown()
    }

    // MARK: - Test 1: Initial State

    func testInitialState() {
        // Initially, scrubbing should not be active
        XCTAssertFalse(scrubController.isScrubbing)
        XCTAssertEqual(scrubController.scrubSpeed, 0.0)
    }

    // MARK: - Test 2: Start Scrubbing

    func testStartScrubbing() {
        // Start scrubbing at position 100
        scrubController.startScrubbing(at: 100)

        // Verify scrubbing state is updated
        XCTAssertTrue(scrubController.isScrubbing)
        XCTAssertEqual(scrubController.scrubSpeed, 0.0)

        // EditorState should reflect scrubbing state
        XCTAssertTrue(EditorState.shared.isScrubbing)
    }

    // MARK: - Test 3: Update Scrub Forward Slow

    func testUpdateScrubForwardSlow() {
        // Start scrubbing
        scrubController.startScrubbing(at: 100)

        // Update with small forward movement (simulating slow drag)
        let speed = scrubController.updateScrub(at: 110) // Small delta

        // Should return positive speed for forward movement
        XCTAssertTrue(speed > 0)
        XCTAssertFalse(speed > 1.0) // Slow movement should not exceed 1x

        // EditorState should have updated playback rate
        XCTAssertEqual(EditorState.shared.playbackRate, Float(speed))
    }

    // MARK: - Test 4: Update Scrub Backward Slow

    func testUpdateScrubBackwardSlow() {
        // Start scrubbing
        scrubController.startScrubbing(at: 100)

        // Update with small backward movement (simulating slow backward drag)
        let speed = scrubController.updateScrub(at: 90) // Small delta

        // Should return negative speed for backward movement
        XCTAssertTrue(speed < 0)
        XCTAssertFalse(abs(speed) > 1.0) // Slow backward movement should not exceed -1x

        // EditorState should have updated playback rate
        XCTAssertEqual(EditorState.shared.playbackRate, Float(speed))
    }

    // MARK: - Test 5: Update Scrub Fast

    func testUpdateScrubFast() {
        // Start scrubbing
        scrubController.startScrubbing(at: 100)

        // Update with large forward movement (simulating fast drag)
        let speed = scrubController.updateScrub(at: 300) // Large delta

        // Should return positive speed > 1 for fast movement
        XCTAssertTrue(speed > 1.0)
        XCTAssertTrue(speed <= 4.0) // Should not exceed 4x maximum
        XCTAssertTrue(EditorState.shared.playbackRate, Float(speed))
    }

    // MARK: - Test 6: End Scrubbing

    func testEndScrubbing() {
        // Start scrubbing
        scrubController.startScrubbing(at: 100)

        // Update scrubbing
        _ = scrubController.updateScrub(at: 150)

        // End scrubbing
        scrubController.endScrubbing()

        // Verify scrubbing state is reset
        XCTAssertFalse(scrubController.isScrubbing)
        XCTAssertEqual(scrubController.scrubSpeed, 0.0)

        // EditorState should reflect scrubbing ended
        XCTAssertFalse(EditorState.shared.isScrubbing)
        XCTAssertEqual(EditorState.shared.playbackRate, 0)
    }

    // MARK: - Test 7: Update Scrub When Not Scrubbing

    func testUpdateScrubWhenNotScrubbing() {
        // Don't start scrubbing

        // Try to update scrubbing
        let speed = scrubController.updateScrub(at: 100)

        // Should return 0 when not scrubbing
        XCTAssertEqual(speed, 0.0)
    }

    // MARK: - Test 8: Multiple Updates with Increasing Speed

    func testMultipleUpdatesWithIncreasingSpeed() {
        // Start scrubbing
        scrubController.startScrubbing(at: 100)

        // First update - small movement
        let speed1 = scrubController.updateScrub(at: 120) // 20 point delta

        // Second update - medium movement
        let speed2 = scrubController.updateScrub(at: 160) // 40 point delta

        // Third update - large movement
        let speed3 = scrubController.updateScrub(at: 260) // 100 point delta

        // Speed should increase with each update
        XCTAssertTrue(speed1 > 0)
        XCTAssertTrue(speed2 > speed1)
        XCTAssertTrue(speed3 > speed2)
        XCTAssertTrue(speed3 <= 4.0) // Should not exceed maximum
    }
}