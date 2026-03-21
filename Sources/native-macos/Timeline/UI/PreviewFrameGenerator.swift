import Foundation
import CoreImage

/// Generates test preview frames for transition preview
enum PreviewFrameGenerator {
    /// Creates leading frame (system blue)
    static func makeLeadingFrame(size: CGSize) -> CIImage {
        let color = CIColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1.0)
        let image = CIImage(color: color)
        return image.cropped(to: CGRect(origin: .zero, size: size))
    }

    /// Creates trailing frame (system orange)
    static func makeTrailingFrame(size: CGSize) -> CIImage {
        let color = CIColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 1.0)
        let image = CIImage(color: color)
        return image.cropped(to: CGRect(origin: .zero, size: size))
    }
}
