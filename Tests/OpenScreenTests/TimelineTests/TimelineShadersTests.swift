import XCTest
import Foundation
@testable import OpenScreen

final class TimelineShadersTests: XCTestCase {
    func testTimelineShadersMetallibExists() {
        // Test that the TimelineShaders.metallib file exists in bundle
        let bundle = Bundle.module
        let metallibPath = bundle.path(forResource: "TimelineShaders", ofType: "metallib")

        XCTAssertNotNil(metallibPath, "TimelineShaders.metallib should exist in bundle")
    }

    func testTimelineShadersFileSize() {
        // Test that the metallib file has reasonable size
        let bundle = Bundle.module
        if let metallibPath = bundle.path(forResource: "TimelineShaders", ofType: "metallib") {
            let attributes = try? FileManager.default.attributesOfItem(atPath: metallibPath)
            let fileSize = attributes?[.size] as? UInt64

            XCTAssertNotNil(fileSize, "File size should be retrievable")
            XCTAssertTrue(fileSize! > 1000, "Metallib file should be at least 1KB")
        } else {
            XCTFail("TimelineShaders.metallib not found")
        }
    }
}
