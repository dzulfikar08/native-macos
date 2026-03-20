import XCTest
import SwiftUI
import CoreMedia
@testable import OpenScreen

@MainActor
final class DeleteTransitionOperationTests: XCTestCase {
    var editorState: EditorState!

    override func setUp() async throws {
        try await super.setUp()
        editorState = EditorState.createTestState()
    }

    // MARK: - Deletion Tests

    func testDeleteTransitionOperation() {
        let transition = TestDataFactory.makeTestTransition()
        editorState.addTransition(transition)

        let operation = DeleteTransitionOperation(
            transitionID: transition.id,
            editorState: editorState
        )

        try! operation.execute()

        XCTAssertNil(editorState.transitions.first(where: { $0.id == transition.id }))
        XCTAssertEqual(editorState.transitions.count, 0)
    }

    // MARK: - Undo Tests

    func testDeleteTransitionUndo() {
        let transition = TestDataFactory.makeTestTransition()
        editorState.addTransition(transition)

        let operation = DeleteTransitionOperation(
            transitionID: transition.id,
            editorState: editorState
        )

        try! operation.execute()
        try! operation.undo()

        XCTAssertNotNil(editorState.transitions.first(where: { $0.id == transition.id }))
        XCTAssertEqual(editorState.transitions.count, 1)
    }

    // MARK: - Redo Tests

    func testDeleteTransitionRedo() {
        let transition = TestDataFactory.makeTestTransition()
        editorState.addTransition(transition)

        let operation = DeleteTransitionOperation(
            transitionID: transition.id,
            editorState: editorState
        )

        try! operation.execute()
        try! operation.undo()
        try! operation.redo()

        XCTAssertNil(editorState.transitions.first(where: { $0.id == transition.id }))
        XCTAssertEqual(editorState.transitions.count, 0)
    }
}
