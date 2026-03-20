import XCTest
@testable import OpenScreen

final class TimelineColorTests: XCTestCase {
    func testInitFromNSColor() {
        let nsColor = NSColor(red: 0.5, green: 0.75, blue: 1.0, alpha: 0.8)
        let timelineColor = TimelineColor(from: nsColor)

        XCTAssertEqual(timelineColor.red, 0.5, accuracy: 0.001)
        XCTAssertEqual(timelineColor.green, 0.75, accuracy: 0.001)
        XCTAssertEqual(timelineColor.blue, 1.0, accuracy: 0.001)
        XCTAssertEqual(timelineColor.alpha, 0.8, accuracy: 0.001)
    }

    func testConversionToNSColor() {
        let timelineColor = TimelineColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0)
        let nsColor = timelineColor.nsColor

        let convertedColor = nsColor.usingColorSpace(.deviceRGB)!
        XCTAssertEqual(convertedColor.redComponent, 1.0, accuracy: 0.001)
        XCTAssertEqual(convertedColor.greenComponent, 0.5, accuracy: 0.001)
        XCTAssertEqual(convertedColor.blueComponent, 0.0, accuracy: 0.001)
        XCTAssertEqual(convertedColor.alphaComponent, 1.0, accuracy: 0.001)
    }

    func testCodableConformance() {
        let original = TimelineColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.8)
        let encoder = JSONEncoder()
        let data = try! encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try! decoder.decode(TimelineColor.self, from: data)

        XCTAssertEqual(original.red, decoded.red, accuracy: 0.001)
        XCTAssertEqual(original.green, decoded.green, accuracy: 0.001)
        XCTAssertEqual(original.blue, decoded.blue, accuracy: 0.001)
        XCTAssertEqual(original.alpha, decoded.alpha, accuracy: 0.001)
    }

    func testPredefinedColors() {
        XCTAssertEqual(TimelineColor.blue.red, 0.0, accuracy: 0.001)
        XCTAssertEqual(TimelineColor.blue.green, 0.478, accuracy: 0.001)
        XCTAssertEqual(TimelineColor.blue.blue, 1.0, accuracy: 0.001)

        XCTAssertEqual(TimelineColor.green.red, 0.204, accuracy: 0.001)
        XCTAssertEqual(TimelineColor.green.green, 0.780, accuracy: 0.001)
        XCTAssertEqual(TimelineColor.green.blue, 0.349, accuracy: 0.001)
    }

    func testSendableConformance() async {
        let color = TimelineColor.blue
        let isolatedColor = await MainActor.run { color }
        XCTAssertEqual(color.red, isolatedColor.red, accuracy: 0.001)
    }
}
