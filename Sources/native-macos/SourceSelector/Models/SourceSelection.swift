import Foundation
import CoreGraphics

/// Represents a selected source for recording or editing
enum SourceSelection: Sendable {
    case screen(displayID: CGDirectDisplayID, displayName: String)
    case webcam(cameras: [CameraDevice], settings: WebcamRecordingSettings)
    // Future phases:
    // case window(windowID: CGWindowID, windowName: String, ownerName: String)
    case videoFile(url: URL)
}

extension SourceSelection: Equatable {
    static func == (lhs: SourceSelection, rhs: SourceSelection) -> Bool {
        switch (lhs, rhs) {
        case (.screen(let id1, let name1), .screen(let id2, let name2)):
            return id1 == id2 && name1 == name2
        case (.webcam(let cams1, let settings1), .webcam(let cams2, let settings2)):
            return cams1.map(\.id) == cams2.map(\.id) && settings1.qualityPreset == settings2.qualityPreset
        case (.videoFile(let url1), .videoFile(let url2)):
            return url1 == url2
        default:
            return false
        }
    }
}
