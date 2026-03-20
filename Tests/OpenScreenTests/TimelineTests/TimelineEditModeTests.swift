import XCTest
@testable import OpenScreen

final class TimelineEditModeTests: XCTestCase {

    func testEnumCasesExist() {
        // Test that both required enum cases exist with correct raw values
        XCTAssertEqual(TimelineEditMode.singleAsset.rawValue, "singleAsset")
        XCTAssertEqual(TimelineEditMode.multiClip.rawValue, "multiClip")
    }

    func testEnumIsCodable() {
        // Test that TimelineEditMode conforms to Codable
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // Test encoding
        let original = TimelineEditMode.singleAsset
        let encodedData = try! encoder.encode(original)

        // Test decoding
        let decoded = try! decoder.decode(TimelineEditMode.self, from: encodedData)
        XCTAssertEqual(decoded, original)

        // Test multiClip case as well
        let originalMulti = TimelineEditMode.multiClip
        let encodedMultiData = try! encoder.encode(originalMulti)
        let decodedMulti = try! decoder.decode(TimelineEditMode.self, from: encodedMultiData)
        XCTAssertEqual(decodedMulti, originalMulti)
    }

    func testEnumIsSendable() {
        // Test basic Sendable conformance by ensuring the enum can be used in concurrent contexts
        let editMode = TimelineEditMode.singleAsset
        DispatchQueue.concurrentPerform(iterations: 10) { _ in
            // This should compile without issues if Sendable is properly conformed
            let _ = editMode
        }
    }
}