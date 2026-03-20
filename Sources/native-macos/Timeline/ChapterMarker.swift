import Foundation
import AVFoundation

struct ChapterMarker: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    var name: String
    var time: CMTime
    var notes: String?
    var color: TimelineColor

    init(id: UUID = UUID(), name: String, time: CMTime, notes: String? = nil, color: TimelineColor) {
        self.id = id
        self.name = name
        self.time = time
        self.notes = notes
        self.color = color
    }
}

// MARK: - Marker Error

enum MarkerError: LocalizedError {
    case tooManyMarkers(limit: Int)
    case invalidTime

    var errorDescription: String? {
        switch self {
        case .tooManyMarkers(let limit):
            return "Cannot add more than \(limit) markers"
        case .invalidTime:
            return "Marker time must be within video duration"
        }
    }
}

// MARK: - Chapter Marker Validator

struct ChapterMarkerValidator {
    private let maximumCount: Int

    init(maximumCount: Int = 1000) {
        self.maximumCount = maximumCount
    }

    func validateCount(existingCount: Int) throws {
        if existingCount >= maximumCount {
            throw MarkerError.tooManyMarkers(limit: maximumCount)
        }
    }

    func validate(time: CMTime, videoDuration: CMTime) throws {
        if time < CMTime.zero || time > videoDuration {
            throw MarkerError.invalidTime
        }
    }
}
