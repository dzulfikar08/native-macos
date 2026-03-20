import XCTest
import Foundation
@testable import OpenScreen

/// Mock operation for testing
class MockOperation: ClipOperation {
    let description: String
    let timestamp: Date
    private var executeCount = 0
    private var undoCount = 0
    private var redoCount = 0

    init(description: String = "Mock Operation", timestamp: Date = Date()) {
        self.description = description
        self.timestamp = timestamp
    }

    func execute() throws {
        executeCount += 1
    }

    func undo() throws {
        undoCount += 1
    }

    func redo() throws {
        redoCount += 1
    }

    // Test helpers
    var executeCallCount: Int { executeCount }
    var undoCallCount: Int { undoCount }
    var redoCallCount: Int { redoCount }
}

/// Failing mock operation for error testing
class FailingOperation: ClipOperation {
    let description: String = "Failing Operation"
    let timestamp: Date = Date()

    func execute() throws {
        throw ClipError.operationFailed
    }

    func undo() throws {
        throw ClipError.operationFailed
    }

    func redo() throws {
        throw ClipError.operationFailed
    }
}

@MainActor
final class ClipUndoManagerTests: XCTestCase {
    var editorState: EditorState!
    var undoManager: ClipUndoManager!

    override func setUp() async throws {
        editorState = EditorState.createTestState()
        undoManager = ClipUndoManager(editorState: editorState)
    }

    override func tearDown() async throws {
        editorState = nil
        undoManager = nil
    }

    // MARK: - Test 1: Initial State

    func testManagerInitialState() {
        // Verify initial state is clean
        XCTAssertFalse(undoManager.canUndo, "Should not be able to undo initially")
        XCTAssertFalse(undoManager.canRedo, "Should not be able to redo initially")
        XCTAssertTrue(undoManager.undoStack.isEmpty, "Undo stack should be empty initially")
        XCTAssertTrue(undoManager.redoStack.isEmpty, "Redo stack should be empty initially")
        XCTAssertNil(undoManager.undoDescription, "Undo description should be nil initially")
        XCTAssertNil(undoManager.redoDescription, "Redo description should be nil initially")
    }

    // MARK: - Test 2: Execute Operation

    func testExecuteOperationAddsToUndoStack() throws {
        let operation = MockOperation(description: "Test Operation")

        try undoManager.executeOperation(operation)

        XCTAssertEqual(undoManager.undoStack.count, 1, "Should have one operation in undo stack")
        XCTAssertTrue(undoManager.canUndo, "Should be able to undo after executing operation")
        XCTAssertFalse(undoManager.canRedo, "Should not be able to redo initially")
        XCTAssertEqual(undoManager.undoDescription, "Test Operation", "Undo description should match operation")
        XCTAssertEqual(operation.executeCallCount, 1, "Operation should have been executed once")
    }

    // MARK: - Test 3: Execute Clears Redo Stack

    func testExecuteOperationClearsRedoStack() throws {
        let op1 = MockOperation(description: "Operation 1")
        let op2 = MockOperation(description: "Operation 2")

        // Execute first operation
        try undoManager.executeOperation(op1)

        // Undo it
        try undoManager.undo()

        XCTAssertEqual(undoManager.redoStack.count, 1, "Should have one operation in redo stack")

        // Execute second operation (should clear redo stack)
        try undoManager.executeOperation(op2)

        XCTAssertTrue(undoManager.redoStack.isEmpty, "Redo stack should be cleared after new operation")
        XCTAssertEqual(undoManager.undoStack.count, 1, "Should have one operation in undo stack")
        XCTAssertEqual(undoManager.undoStack.last?.description, "Operation 2", "Undo stack should contain new operation")
    }

    // MARK: - Test 4: Undo Operation

    func testUndoMovesOperationToRedoStack() throws {
        let operation = MockOperation(description: "Test Operation")

        // Execute operation
        try undoManager.executeOperation(operation)

        // Undo operation
        try undoManager.undo()

        XCTAssertTrue(undoManager.undoStack.isEmpty, "Undo stack should be empty after undo")
        XCTAssertEqual(undoManager.redoStack.count, 1, "Redo stack should contain the operation")
        XCTAssertTrue(undoManager.canRedo, "Should be able to redo")
        XCTAssertFalse(undoManager.canUndo, "Should not be able to undo")
        XCTAssertEqual(operation.undoCallCount, 1, "Operation should have been undone once")
    }

    // MARK: - Test 5: Redo Operation

    func testRedoMovesOperationToUndoStack() throws {
        let operation = MockOperation(description: "Test Operation")

        // Execute and undo
        try undoManager.executeOperation(operation)
        try undoManager.undo()

        // Redo operation
        try undoManager.redo()

        XCTAssertEqual(undoManager.undoStack.count, 1, "Undo stack should contain the operation")
        XCTAssertTrue(undoManager.undoStack.isEmpty, "Redo stack should be empty after redo")
        XCTAssertTrue(undoManager.canUndo, "Should be able to undo")
        XCTAssertFalse(undoManager.canRedo, "Should not be able to redo")
        XCTAssertEqual(operation.redoCallCount, 1, "Operation should have been redone once")
    }

    // MARK: - Test 6: Clear History

    func testClearHistoryEmptiesBothStacks() throws {
        let op1 = MockOperation(description: "Operation 1")
        let op2 = MockOperation(description: "Operation 2")

        // Execute two operations
        try undoManager.executeOperation(op1)
        try undoManager.executeOperation(op2)

        // Undo one
        try undoManager.undo()

        // Verify both stacks have items
        XCTAssertEqual(undoManager.undoStack.count, 1, "Should have one operation in undo stack")
        XCTAssertEqual(undoManager.redoStack.count, 1, "Should have one operation in redo stack")

        // Clear history
        undoManager.clearHistory()

        // Verify both stacks are empty
        XCTAssertTrue(undoManager.undoStack.isEmpty, "Undo stack should be empty after clear")
        XCTAssertTrue(undoManager.redoStack.isEmpty, "Redo stack should be empty after clear")
        XCTAssertFalse(undoManager.canUndo, "Should not be able to undo after clear")
        XCTAssertFalse(undoManager.canRedo, "Should not be able to redo after clear")
    }

    // MARK: - Test 7: History Limit Enforcement

    func testHistoryLimitEnforcement() throws {
        // Test fixed count limit
        undoManager.historyLimit = .fixedCount(3)

        let now = Date()
        let op1 = MockOperation(description: "Op 1", timestamp: now.addingTimeInterval(-10))
        let op2 = MockOperation(description: "Op 2", timestamp: now.addingTimeInterval(-8))
        let op3 = MockOperation(description: "Op 3", timestamp: now.addingTimeInterval(-6))
        let op4 = MockOperation(description: "Op 4", timestamp: now.addingTimeInterval(-4))
        let op5 = MockOperation(description: "Op 5", timestamp: now.addingTimeInterval(-2))

        // Execute 5 operations
        try undoManager.executeOperation(op1)
        try undoManager.executeOperation(op2)
        try undoManager.executeOperation(op3)
        try undoManager.executeOperation(op4)
        try undoManager.executeOperation(op5)

        XCTAssertEqual(undoManager.undoStack.count, 3, "Should keep only 3 most recent operations")
        XCTAssertEqual(undoManager.undoStack[0].description, "Op 3", "Oldest operation should be Op 3")
        XCTAssertEqual(undoManager.undoStack[2].description, "Op 5", "Newest operation should be Op 5")

        // Test unlimited
        undoManager.clearHistory()
        undoManager.historyLimit = .unlimited

        try undoManager.executeOperation(op1)
        try undoManager.executeOperation(op2)
        try undoManager.executeOperation(op3)
        try undoManager.executeOperation(op4)
        try undoManager.executeOperation(op5)

        XCTAssertEqual(undoManager.undoStack.count, 5, "Should keep all operations with unlimited limit")

        // Test hybrid limit (maxOps + timeWindow)
        undoManager.clearHistory()
        undoManager.historyLimit = .hybrid(maxOps: 10, timeWindow: 5)

        let oldOp = MockOperation(description: "Old Op", timestamp: now.addingTimeInterval(-100))
        let recentOp1 = MockOperation(description: "Recent 1", timestamp: now.addingTimeInterval(-3))
        let recentOp2 = MockOperation(description: "Recent 2", timestamp: now.addingTimeInterval(-1))

        try undoManager.executeOperation(oldOp)
        try undoManager.executeOperation(recentOp1)
        try undoManager.executeOperation(recentOp2)

        XCTAssertEqual(undoManager.undoStack.count, 2, "Should remove operations outside time window")
        XCTAssertTrue(undoManager.undoStack.allSatisfy { $0.description != "Old Op" }, "Old operation should be removed")
    }

    // MARK: - Additional Error Tests

    func testUndoWhenNothingToUndo() throws {
        let operation = MockOperation()

        XCTAssertThrowsError(try undoManager.undo(), "Should throw when trying to undo with empty stack") { error in
            guard let undoError = error as? UndoError else {
                XCTFail("Should throw UndoError")
                return
            }
            XCTAssertEqual(undoError, UndoError.nothingToUndo, "Should be nothingToUndo error")
        }
    }

    func testRedoWhenNothingToRedo() throws {
        let operation = MockOperation()

        XCTAssertThrowsError(try undoManager.redo(), "Should throw when trying to redo with empty stack") { error in
            guard let undoError = error as? UndoError else {
                XCTFail("Should throw UndoError")
                return
            }
            XCTAssertEqual(undoError, UndoError.nothingToRedo, "Should be nothingToRedo error")
        }
    }

    func testFailedExecuteDoesNotAddToUndoStack() {
        let failingOp = FailingOperation()

        XCTAssertThrowsError(try undoManager.executeOperation(failingOp), "Should throw when operation fails")
        XCTAssertTrue(undoManager.undoStack.isEmpty, "Failed operation should not be added to undo stack")
    }

    func testFailedUndoRestoresOperationToUndoStack() throws {
        let op1 = MockOperation(description: "Op 1")
        let failingOp = FailingOperation()

        try undoManager.executeOperation(op1)
        try undoManager.executeOperation(failingOp)

        XCTAssertEqual(undoManager.undoStack.count, 2, "Should have 2 operations in undo stack")

        // First undo should succeed
        try undoManager.undo()
        XCTAssertEqual(undoManager.undoStack.count, 1, "Should have 1 operation after first undo")

        // Second undo will fail (failingOp.undo throws)
        XCTAssertThrowsError(try undoManager.undo(), "Should throw when operation undo fails")

        // The operation should be restored to undo stack
        XCTAssertEqual(undoManager.undoStack.count, 1, "Operation should be restored to undo stack after failed undo")
    }

    func testFailedRedoRestoresOperationToRedoStack() throws {
        let failingOp = FailingOperation()

        try undoManager.executeOperation(failingOp)
        try undoManager.undo()

        XCTAssertEqual(undoManager.redoStack.count, 1, "Should have 1 operation in redo stack")

        // Redo will fail (failingOp.redo throws)
        XCTAssertThrowsError(try undoManager.redo(), "Should throw when operation redo fails")

        // The operation should be restored to redo stack
        XCTAssertEqual(undoManager.redoStack.count, 1, "Operation should be restored to redo stack after failed redo")
    }
}

// Helper extension for ClipError
extension ClipError {
    static let operationFailed = ClipError.invalidSplitPoint
}
