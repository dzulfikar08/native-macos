import Foundation
import AVFoundation

struct LoopRegion: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    var name: String
    var timeRange: ClosedRange<CMTime>
    var color: TimelineColor
    var isActive: Bool
    var useInOutPoints: Bool

    init(id: UUID = UUID(), name: String, timeRange: ClosedRange<CMTime>, color: TimelineColor, isActive: Bool = false, useInOutPoints: Bool = false) {
        self.id = id
        self.name = name
        self.timeRange = timeRange
        self.color = color
        self.isActive = isActive
        self.useInOutPoints = useInOutPoints
    }

    // MARK: - Custom Coding for timeRange

    enum CodingKeys: String, CodingKey {
        case id, name, timeRange, color, isActive, useInOutPoints
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        color = try container.decode(TimelineColor.self, forKey: .color)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        useInOutPoints = try container.decode(Bool.self, forKey: .useInOutPoints)

        // Decode timeRange as custom struct
        let rangeData = try container.decode(TimeRangeCodable.self, forKey: .timeRange)
        timeRange = rangeData.lowerBound...rangeData.upperBound
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(color, forKey: .color)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(useInOutPoints, forKey: .useInOutPoints)

        // Encode timeRange as custom struct
        let rangeData = TimeRangeCodable(lowerBound: timeRange.lowerBound, upperBound: timeRange.upperBound)
        try container.encode(rangeData, forKey: .timeRange)
    }

    // Helper struct for encoding/decoding ClosedRange<CMTime>
    private struct TimeRangeCodable: Codable {
        let lowerBound: CMTime
        let upperBound: CMTime
    }
}

// MARK: - Loop Error

enum LoopError: LocalizedError {
    case tooManyLoops(limit: Int)
    case durationTooShort(minimum: Double)
    case invalidRange
    case outOfBounds

    var errorDescription: String? {
        switch self {
        case .tooManyLoops(let limit):
            return "Maximum number of loop regions reached (\(limit)). Delete existing loops to create new ones."
        case .durationTooShort(let minimum):
            return "Loop duration must be at least \(minimum) seconds"
        case .invalidRange:
            return "Loop start time must be before end time"
        case .outOfBounds:
            return "Loop region must be within video duration"
        }
    }
}

// MARK: - Loop Region Validator

struct LoopRegionValidator {
    private let minimumDuration: CMTime
    private let maximumCount: Int

    init(minimumDuration: Double = 0.1, maximumCount: Int = 50) {
        self.minimumDuration = CMTime(seconds: minimumDuration, preferredTimescale: 600)
        self.maximumCount = maximumCount
    }

    func validate(range: ClosedRange<CMTime>, existingCount: Int = 0, videoDuration: CMTime? = nil) throws {
        if existingCount >= maximumCount {
            throw LoopError.tooManyLoops(limit: maximumCount)
        }

        let duration = range.upperBound - range.lowerBound
        if duration < minimumDuration {
            throw LoopError.durationTooShort(minimum: CMTimeGetSeconds(minimumDuration))
        }

        if range.upperBound <= range.lowerBound {
            throw LoopError.invalidRange
        }

        if let duration = videoDuration {
            if range.lowerBound < CMTime.zero || range.upperBound > duration {
                throw LoopError.outOfBounds
            }
        }
    }
}
