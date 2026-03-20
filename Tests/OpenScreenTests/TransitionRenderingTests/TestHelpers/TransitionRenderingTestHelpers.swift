import XCTest
import AVFoundation
import CoreVideo
@testable import OpenScreen

/// Test helper utilities for transition rendering tests
enum TransitionRenderingTestHelpers {

    /// Creates a test pixel buffer filled with a solid color
    /// - Parameters:
    ///   - width: Buffer width in pixels (default: 1920)
    ///   - height: Buffer height in pixels (default: 1080)
    ///   - color: RGB color to fill the buffer with
    /// - Returns: A CVPixelBuffer filled with the specified color
    static func createTestPixelBuffer(
        width: Int = 1920,
        height: Int = 1080,
        color: TestColor
    ) throws -> CVPixelBuffer {
        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            attributes as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            throw TransitionError.invalidParameters(reason: "Failed to create test pixel buffer")
        }

        // Lock the buffer for writing
        CVPixelBufferLockBaseAddress(buffer, [])
        defer {
            CVPixelBufferUnlockBaseAddress(buffer, [])
        }

        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
            throw TransitionError.invalidParameters(reason: "Failed to get pixel buffer base address")
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let pixelData = baseAddress.assumingMemoryBound(to: UInt8.self)

        // Fill the buffer with the specified color
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = (y * bytesPerRow) + (x * 4)
                pixelData[pixelIndex + 0] = color.blue     // B
                pixelData[pixelIndex + 1] = color.green    // G
                pixelData[pixelIndex + 2] = color.red      // R
                pixelData[pixelIndex + 3] = 255            // A
            }
        }

        return buffer
    }

    /// Extracts the dominant color from the center region of a pixel buffer
    /// - Parameter buffer: The pixel buffer to sample
    /// - Returns: The average RGB color from the center 10x10 pixel region
    static func extractDominantColor(from buffer: CVPixelBuffer) throws -> TestColor {
        // Sample from center of the image (10x10 region)
        return try extractColorAt(from: buffer, x: 0.5, y: 0.5, sampleSize: 10)
    }

    /// Extracts color from a specific relative position in the pixel buffer
    /// - Parameters:
    ///   - buffer: The pixel buffer to sample
    ///   - x: Relative X position (0.0 to 1.0, where 0.5 is center)
    ///   - y: Relative Y position (0.0 to 1.0, where 0.5 is center)
    ///   - sampleSize: Size of the square region to sample (default: 5)
    /// - Returns: The average RGB color from the specified region
    static func extractColorAt(
        from buffer: CVPixelBuffer,
        x: Double,
        y: Double,
        sampleSize: Int = 5
    ) throws -> TestColor {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
        }

        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
            throw TransitionError.invalidParameters(reason: "Failed to get pixel buffer base address")
        }

        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let pixelData = baseAddress.assumingMemoryBound(to: UInt8.self)

        // Calculate center of sample region
        let centerX = Int(x * Double(width))
        let centerY = Int(y * Double(height))
        let halfSample = sampleSize / 2

        var redSum: Double = 0
        var greenSum: Double = 0
        var blueSum: Double = 0
        var pixelCount = 0

        // Sample pixels in the region
        for dy in -halfSample...halfSample {
            for dx in -halfSample...halfSample {
                let px = centerX + dx
                let py = centerY + dy

                // Ensure we're within bounds
                if px >= 0 && px < width && py >= 0 && py < height {
                    let pixelIndex = (py * bytesPerRow) + (px * 4)
                    blueSum += Double(pixelData[pixelIndex + 0])
                    greenSum += Double(pixelData[pixelIndex + 1])
                    redSum += Double(pixelData[pixelIndex + 2])
                    pixelCount += 1
                }
            }
        }

        guard pixelCount > 0 else {
            throw TransitionError.invalidParameters(reason: "No valid pixels sampled")
        }

        return TestColor(
            red: redSum / Double(pixelCount) / 255.0,
            green: greenSum / Double(pixelCount) / 255.0,
            blue: blueSum / Double(pixelCount) / 255.0
        )
    }

    /// Calculates the average luminance of a pixel buffer
    /// - Parameter buffer: The pixel buffer to analyze
    /// - Returns: Average luminance value (0.0 to 1.0)
    static func extractLuminance(from buffer: CVPixelBuffer) throws -> Double {
        let color = try extractDominantColor(from: buffer)
        // Use standard luminance formula: 0.299*R + 0.587*G + 0.114*B
        return 0.299 * color.red + 0.587 * color.green + 0.114 * color.blue
    }
}

/// Simple RGB color representation for testing
struct TestColor {
    var red: Double
    var green: Double
    var blue: Double

    /// Predefined test colors
    static let red = TestColor(red: 1.0, green: 0.0, blue: 0.0)
    static let green = TestColor(red: 0.0, green: 1.0, blue: 0.0)
    static let blue = TestColor(red: 0.0, green: 0.0, blue: 1.0)
    static let black = TestColor(red: 0.0, green: 0.0, blue: 0.0)
    static let white = TestColor(red: 1.0, green: 1.0, blue: 1.0)
}
