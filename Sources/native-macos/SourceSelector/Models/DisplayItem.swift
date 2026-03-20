import AppKit

/// Represents a display device with metadata and optional thumbnail
struct DisplayItem: Identifiable, Equatable, Sendable {
    let id: CGDirectDisplayID
    let name: String
    let width: Int
    let height: Int
    var thumbnail: NSImage?

    var resolution: String {
        "\(width) × \(height)"
    }
}
