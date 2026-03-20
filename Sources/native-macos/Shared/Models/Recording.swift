import Foundation
import CoreGraphics
import CoreMedia

/// Represents a screen recording session
struct Recording: Identifiable, Codable, Sendable {
    let id: UUID
    let url: URL
    let createdAt: Date
    let duration: CMTime
    let displayID: CGDirectDisplayID
    let frameSize: CGSize
    let hasAudio: Bool

    init(
        id: UUID = UUID(),
        url: URL,
        createdAt: Date = Date(),
        duration: CMTime,
        displayID: CGDirectDisplayID,
        frameSize: CGSize,
        hasAudio: Bool
    ) {
        self.id = id
        self.url = url
        self.createdAt = createdAt
        self.duration = duration
        self.displayID = displayID
        self.frameSize = frameSize
        self.hasAudio = hasAudio
    }
}

// MARK: - CMTime Codability
extension CMTime: Codable {
    enum CodingKeys: String, CodingKey {
        case value, timescale, flags, epoch
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let value = try container.decode(Int64.self, forKey: .value)
        let timescale = try container.decode(Int32.self, forKey: .timescale)
        let flags = try container.decode(UInt32.self, forKey: .flags)
        let epoch = try container.decode(Int64.self, forKey: .epoch)

        self.init(
            value: value,
            timescale: timescale,
            flags: CMTimeFlags(rawValue: flags),
            epoch: epoch
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(value, forKey: .value)
        try container.encode(timescale, forKey: .timescale)
        try container.encode(flags.rawValue, forKey: .flags)
        try container.encode(epoch, forKey: .epoch)
    }
}

// MARK: - CGSize Codability
extension CGSize: Codable {
    enum CodingKeys: String, CodingKey {
        case width, height
    }
}