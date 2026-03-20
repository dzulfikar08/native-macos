// Tests/OpenScreenTests/IntegrationTests/Phase23IntegrationTests.swift
import XCTest
import AVFoundation
@testable import OpenScreen

@MainActor
final class Phase23IntegrationTests: XCTestCase {
    var windowController: EditorWindowController!
    var editorState: EditorState!
    var testVideoURL: URL!

    override func setUp() async throws {
        try await super.setUp()

        // Create a temporary test video file
        testVideoURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_video_\(UUID().uuidString).mov")

        // Create a simple test video file (empty file for testing)
        try Data().write(to: testVideoURL)

        // Initialize EditorState with test video URL
        EditorState.initializeShared(with: testVideoURL)
        editorState = EditorState.shared

        // Set a realistic duration for testing
        editorState.duration = CMTime(seconds: 30, preferredTimescale: 600)

        // Initialize window controller
        windowController = EditorWindowController()
    }

    override func tearDown() async throws {
        windowController = nil
        editorState = nil
        EditorState.shared = nil

        // Clean up test video file
        if let url = testVideoURL {
            try? FileManager.default.removeItem(at: url)
        }

        try await super.tearDown()
    }

    func testLoopRegionCreationAndPlayback() async throws {
        // Create loop region
        let loop = LoopRegion(
            name: "Test Loop",
            timeRange: CMTime(seconds: 5)...CMTime(seconds: 10),
            color: .blue,
            isActive: true,
            useInOutPoints: false
        )

        editorState.loopRegions = [loop]
        editorState.activeLoopRegionID = loop.id

        // Start playback
        editorState.isPlaying = true
        editorState.currentTime = CMTime(seconds: 9)

        try await Task.sleep(nanoseconds: 500_000_000)  // 0.5s

        // Should have looped back
        XCTAssertLessThan(editorState.currentTime.seconds, 6)
    }

    func testJKLNavigationWithMarkers() async throws {
        // Add markers
        editorState.chapterMarkers = [
            ChapterMarker(name: "Start", time: CMTime(seconds: 5), notes: nil, color: .blue),
            ChapterMarker(name: "Middle", time: CMTime(seconds: 15), notes: nil, color: .green),
        ]

        let jklController = JKLController(editorState: editorState)

        // Play forward
        jklController.keyDown(.l)
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(editorState.isPlaying)

        // Pause
        jklController.keyDown(.k)
        XCTAssertFalse(editorState.isPlaying)
    }

    func testVariableSpeedScrubbing() async throws {
        let scrubController = ScrubController()
        let startPosition: CGFloat = 100

        scrubController.startScrubbing(at: startPosition)
        XCTAssertTrue(editorState.isScrubbing)

        // Drag forward fast
        let speed = scrubController.updateScrub(at: startPosition + 500)
        XCTAssertGreaterThan(speed, 2.0)

        scrubController.endScrubbing()
        XCTAssertFalse(editorState.isScrubbing)
    }

    func testInOutPointsWithFocusMode() async throws {
        // Set in/out points
        editorState.inPoint = CMTime(seconds: 10)
        editorState.outPoint = CMTime(seconds: 20)

        // Enable focus mode
        editorState.focusMode = .focusOnSelection

        XCTAssertEqual(editorState.focusMode, .focusOnSelection)
        XCTAssertEqual(editorState.inPoint?.seconds, 10)
        XCTAssertEqual(editorState.outPoint?.seconds, 20)
    }

    func testMarkersPanelIntegration() async throws {
        let markersPanel = MarkersPanel()

        editorState.chapterMarkers = [
            ChapterMarker(name: "Chapter 1", time: CMTime(seconds: 5), notes: "Intro", color: .blue),
            ChapterMarker(name: "Chapter 2", time: CMTime(seconds: 15), notes: "Content", color: .green),
        ]

        // Search for specific marker
        markersPanel.searchText = "Chapter 1"
        markersPanel.updateFilteredMarkers()

        XCTAssertEqual(markersPanel.filteredMarkers.count, 1)

        // Select marker to jump
        markersPanel.selectMarker(at: 0)
        XCTAssertEqual(editorState.currentTime.seconds, 5)
    }

    func testPerformanceWithManyMarkers() async throws {
        // Create 500 markers
        var markers: [ChapterMarker] = []
        for i in 0..<500 {
            markers.append(ChapterMarker(
                name: "Marker \(i)",
                time: CMTime(seconds: Double(i) * 0.1),
                notes: nil,
                color: .blue
            ))
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        editorState.chapterMarkers = markers
        let duration = CFAbsoluteTimeGetCurrent() - startTime

        // Should complete in less than 1 second
        XCTAssertLessThan(duration, 1.0)
        XCTAssertEqual(editorState.chapterMarkers.count, 500)
    }

    func testLoopRegionValidation() async throws {
        let validator = LoopRegionValidator()

        // Try to create 51 loops (exceeds maximum)
        var loops: [LoopRegion] = []
        for i in 0..<51 {
            loops.append(LoopRegion(
                name: "Loop \(i)",
                timeRange: CMTime(seconds: Double(i))...CMTime(seconds: Double(i) + 1),
                color: .blue,
                isActive: false,
                useInOutPoints: false
            ))
        }

        // Adding 51st loop should throw
        XCTAssertThrowsError(try validator.validate(
            range: CMTime(seconds: 51)...CMTime(seconds: 52),
            existingCount: 50
        )) { error in
            XCTAssertEqual(error as? LoopError, .tooManyLoops(limit: 50))
        }
    }
}
