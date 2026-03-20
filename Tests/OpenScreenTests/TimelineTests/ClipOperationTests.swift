import XCTest
@testable import OpenScreen
import AVFoundation
import CoreMedia

/// Test helper for ClipOperation protocol tests
@MainActor
class TestClipOperation: BaseClipOperation {
    var executed: Bool = false
    var undone: Bool = false
    var executeCallCount: Int = 0

    override func execute() throws {
        executed = true
        executeCallCount += 1
    }

    override func undo() throws {
        undone = true
        executed = false
    }
}

@MainActor
final class ClipOperationTests: XCTestCase {
    func testBaseClipOperationHasDescription() {
        let state = EditorState.createTestState()
        let manager = ClipManager(editorState: state)
        let operation = TestClipOperation(
            description: "Test Operation",
            editorState: state,
            clipManager: manager
        )

        XCTAssertEqual(operation.description, "Test Operation")
    }

    func testOperationCanBeExecuted() {
        let state = EditorState.createTestState()
        let manager = ClipManager(editorState: state)
        let operation = TestClipOperation(
            description: "Test",
            editorState: state,
            clipManager: manager
        )

        XCTAssertFalse(operation.executed)
        try? operation.execute()
        XCTAssertTrue(operation.executed)
    }

    func testOperationCanBeUndone() {
        let state = EditorState.createTestState()
        let manager = ClipManager(editorState: state)
        let operation = TestClipOperation(
            description: "Test",
            editorState: state,
            clipManager: manager
        )

        try? operation.execute()
        XCTAssertTrue(operation.executed)

        try? operation.undo()
        XCTAssertFalse(operation.executed)
    }

    func testRedoUsesExecute() {
        let state = EditorState.createTestState()
        let manager = ClipManager(editorState: state)
        let operation = TestClipOperation(
            description: "Test",
            editorState: state,
            clipManager: manager
        )

        try? operation.execute()
        XCTAssertEqual(operation.executeCallCount, 1)

        try? operation.redo()
        XCTAssertEqual(operation.executeCallCount, 2)
    }

    func testClipOperationHasTimestamp() {
        let state = EditorState.createTestState()
        let manager = ClipManager(editorState: state)
        let operation = TestClipOperation(
            description: "Test",
            editorState: state,
            clipManager: manager
        )

        XCTAssertNotNil(operation.timestamp)
        XCTAssertTrue(operation.timestamp <= Date())
    }
}
