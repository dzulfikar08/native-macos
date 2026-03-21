import XCTest
import CoreMedia
@testable import OpenScreen

/// Tests for EditorState transition integration
final class EditorStateTransitionTests: XCTestCase {
    var editorState: EditorState!

    override func setUp() {
        super.setUp()
        editorState = EditorState.createTestState()
    }

    override func tearDown() {
        editorState = nil
        super.tearDown()
    }

    // MARK: - Add Transition Tests

    func testAddTransition() {
        let transition = TestDataFactory.makeTestTransition()
        let expectation = XCTestExpectation(description: "Transitions changed notification")

        let observer = NotificationCenter.default.addObserver(
            forName: .transitionsChanged,
            object: editorState,
            queue: .main
        ) { notification in
            XCTAssertEqual(notification.userInfo?["action"] as? String, "add")
            XCTAssertEqual(notification.userInfo?["transitionID"] as? UUID, transition.id)
            expectation.fulfill()
        }

        editorState.addTransition(transition)

        XCTAssertEqual(editorState.transitions.count, 1)
        XCTAssertEqual(editorState.transitions.first?.id, transition.id)

        NotificationCenter.default.removeObserver(observer)
        wait(for: [expectation], timeout: 1.0)
    }

    func testAddMultipleTransitions() {
        let transition1 = TestDataFactory.makeTestTransition()
        let transition2 = TestDataFactory.makeTestTransition()

        editorState.addTransition(transition1)
        editorState.addTransition(transition2)

        XCTAssertEqual(editorState.transitions.count, 2)
    }

    // MARK: - Remove Transition Tests

    func testRemoveTransition() {
        let transition = TestDataFactory.makeTestTransition()
        editorState.addTransition(transition)

        let expectation = XCTestExpectation(description: "Transitions changed notification")

        let observer = NotificationCenter.default.addObserver(
            forName: .transitionsChanged,
            object: editorState,
            queue: .main
        ) { notification in
            XCTAssertEqual(notification.userInfo?["action"] as? String, "remove")
            XCTAssertEqual(notification.userInfo?["transitionID"] as? UUID, transition.id)
            expectation.fulfill()
        }

        editorState.removeTransition(id: transition.id)

        XCTAssertEqual(editorState.transitions.count, 0)

        NotificationCenter.default.removeObserver(observer)
        wait(for: [expectation], timeout: 1.0)
    }

    func testRemoveTransitionClearsSelection() {
        let transition = TestDataFactory.makeTestTransition()
        editorState.addTransition(transition)
        editorState.selectedTransitionID = transition.id

        editorState.removeTransition(id: transition.id)

        XCTAssertNil(editorState.selectedTransitionID)
    }

    func testRemoveNonExistentTransition() {
        let transition = TestDataFactory.makeTestTransition()
        editorState.addTransition(transition)

        let beforeCount = editorState.transitions.count

        // Should not crash or change state
        editorState.removeTransition(id: UUID())

        XCTAssertEqual(editorState.transitions.count, beforeCount)
    }

    // MARK: - Update Transition Tests

    func testUpdateTransition() {
        let transition = TestDataFactory.makeTestTransition()
        editorState.addTransition(transition)

        let expectation = XCTestExpectation(description: "Transitions changed notification")

        let observer = NotificationCenter.default.addObserver(
            forName: .transitionsChanged,
            object: editorState,
            queue: .main
        ) { notification in
            XCTAssertEqual(notification.userInfo?["action"] as? String, "update")
            XCTAssertEqual(notification.userInfo?["transitionID"] as? UUID, transition.id)
            expectation.fulfill()
        }

        let updatedTransition = TransitionClip(
            id: transition.id,
            type: .push,
            duration: CMTime(seconds: 2.0, preferredTimescale: 600),
            leadingClipID: transition.leadingClipID,
            trailingClipID: transition.trailingClipID,
            parameters: .push(direction: .fromTop)
        )

        editorState.updateTransition(updatedTransition)

        XCTAssertEqual(editorState.transitions.count, 1)
        XCTAssertEqual(editorState.transitions.first?.type, .push)

        NotificationCenter.default.removeObserver(observer)
        wait(for: [expectation], timeout: 1.0)
    }

    func testUpdateNonExistentTransition() {
        let transition = TestDataFactory.makeTestTransition()

        // Should not crash or add the transition
        editorState.updateTransition(transition)

        XCTAssertEqual(editorState.transitions.count, 0)
    }

    // MARK: - Query Transitions Tests

    func testTransitionsForClip() {
        let clip1ID = UUID()
        let clip2ID = UUID()
        let clip3ID = UUID()

        let transition1 = TestDataFactory.makeTestTransition(
            leadingClipID: clip1ID,
            trailingClipID: clip2ID
        )
        let transition2 = TestDataFactory.makeTestTransition(
            leadingClipID: clip2ID,
            trailingClipID: clip3ID
        )
        let transition3 = TestDataFactory.makeTestTransition(
            leadingClipID: clip3ID,
            trailingClipID: UUID()
        )

        editorState.addTransition(transition1)
        editorState.addTransition(transition2)
        editorState.addTransition(transition3)

        let clip2Transitions = editorState.transitions(for: clip2ID)

        XCTAssertEqual(clip2Transitions.count, 2)
        XCTAssertTrue(clip2Transitions.contains { $0.id == transition1.id })
        XCTAssertTrue(clip2Transitions.contains { $0.id == transition2.id })
    }

    func testTransitionBetweenClips() {
        let clip1ID = UUID()
        let clip2ID = UUID()

        let transition = TestDataFactory.makeTestTransition(
            leadingClipID: clip1ID,
            trailingClipID: clip2ID
        )
        editorState.addTransition(transition)

        let found = editorState.transition(between: clip1ID, and: clip2ID)

        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, transition.id)
    }

    func testTransitionBetweenClipsReverseOrder() {
        let clip1ID = UUID()
        let clip2ID = UUID()

        let transition = TestDataFactory.makeTestTransition(
            leadingClipID: clip1ID,
            trailingClipID: clip2ID
        )
        editorState.addTransition(transition)

        // Should find regardless of order
        let found = editorState.transition(between: clip2ID, and: clip1ID)

        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, transition.id)
    }

    func testTransitionBetweenNonExistentClips() {
        let clip1ID = UUID()
        let clip2ID = UUID()

        let found = editorState.transition(between: clip1ID, and: clip2ID)

        XCTAssertNil(found)
    }

    // MARK: - Selection Tests

    func testSelectTransition() {
        let transition = TestDataFactory.makeTestTransition()
        editorState.addTransition(transition)

        let expectation = XCTestExpectation(description: "Selection changed notification")

        let observer = NotificationCenter.default.addObserver(
            forName: .transitionSelectionChanged,
            object: editorState,
            queue: .main
        ) { notification in
            XCTAssertEqual(notification.userInfo?["selectedTransitionID"] as? UUID, transition.id)
            expectation.fulfill()
        }

        editorState.selectedTransitionID = transition.id

        XCTAssertEqual(editorState.selectedTransitionID, transition.id)

        NotificationCenter.default.removeObserver(observer)
        wait(for: [expectation], timeout: 1.0)
    }

    func testDeselectTransition() {
        let transition = TestDataFactory.makeTestTransition()
        editorState.addTransition(transition)
        editorState.selectedTransitionID = transition.id

        let expectation = XCTestExpectation(description: "Selection changed notification")

        let observer = NotificationCenter.default.addObserver(
            forName: .transitionSelectionChanged,
            object: editorState,
            queue: .main
        ) { notification in
            XCTAssertNil(notification.userInfo?["selectedTransitionID"] as? UUID)
            expectation.fulfill()
        }

        editorState.selectedTransitionID = nil

        XCTAssertNil(editorState.selectedTransitionID)

        NotificationCenter.default.removeObserver(observer)
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Overlap Calculation Tests

    func testCalculateOverlapWithOverlappingClips() {
        let clip1ID = UUID()
        let clip2ID = UUID()

        // Create clips with overlap
        let clip1 = TestDataFactory.makeTestVideoClip(
            id: clip1ID,
            timelineStart: .zero
        )
        let clip2 = TestDataFactory.makeTestVideoClip(
            id: clip2ID,
            timelineStart: CMTime(seconds: 5.0, preferredTimescale: 600),
            sourceDuration: 10
        )

        // Create a track with these clips
        let track = ClipTrack(
            id: UUID(),
            type: .video,
            name: "Video Track",
            clips: [clip1, clip2]
        )
        editorState.clipTracks = [track]

        let overlap = editorState.calculateOverlap(between: clip1ID, and: clip2ID)

        // Clip 1: 0-10 seconds, Clip 2: 5-15 seconds
        // Overlap should be 5-10 seconds (5 second duration)
        let expectedDuration = CMTime(seconds: 5.0, preferredTimescale: 600)
        XCTAssertEqual(overlap.duration, expectedDuration)
    }

    func testCalculateOverlapWithNonOverlappingClips() {
        let clip1ID = UUID()
        let clip2ID = UUID()

        // Create clips without overlap
        let clip1 = TestDataFactory.makeTestVideoClip(
            id: clip1ID,
            timelineStart: .zero,
            sourceDuration: 5
        )
        let clip2 = TestDataFactory.makeTestVideoClip(
            id: clip2ID,
            timelineStart: CMTime(seconds: 10.0, preferredTimescale: 600),
            sourceDuration: 5
        )

        let track = ClipTrack(
            id: UUID(),
            type: .video,
            name: "Video Track",
            clips: [clip1, clip2]
        )
        editorState.clipTracks = [track]

        let overlap = editorState.calculateOverlap(between: clip1ID, and: clip2ID)

        XCTAssertEqual(overlap.duration, .zero)
    }

    func testCalculateOverlapWithMissingClip() {
        let clip1ID = UUID()
        let clip2ID = UUID()

        let clip1 = TestDataFactory.makeTestVideoClip(id: clip1ID)
        let track = ClipTrack(
            id: UUID(),
            type: .video,
            name: "Video Track",
            clips: [clip1]
        )
        editorState.clipTracks = [track]

        // clip2 doesn't exist
        let overlap = editorState.calculateOverlap(between: clip1ID, and: clip2ID)

        XCTAssertEqual(overlap.duration, .zero)
    }

    // MARK: - Published Properties Tests

    func testTransitionsArrayIsPublished() {
        let transition = TestDataFactory.makeTestTransition()

        let expectation = XCTestExpectation(description: "Transitions changed notification")
        let observer = NotificationCenter.default.addObserver(
            forName: .transitionsChanged,
            object: editorState,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }

        editorState.addTransition(transition)

        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }

    func testSelectedTransitionIDIsPublished() {
        let transition = TestDataFactory.makeTestTransition()
        editorState.addTransition(transition)

        let expectation = XCTestExpectation(description: "Selection changed notification")
        let observer = NotificationCenter.default.addObserver(
            forName: .transitionSelectionChanged,
            object: editorState,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }

        editorState.selectedTransitionID = transition.id

        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }
}
