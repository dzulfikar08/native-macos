import Foundation

/// Errors related to clip operations
enum ClipError: LocalizedError, Equatable {
    case clipNotFound
    case trackNotFound
    case invalidSplitPoint
    case trimExceedsSource
    case wouldOverlap
    case invalidSpeed
    case slipExceedsAsset
    case alreadyInMultiClipMode
    case alreadyInSingleAssetMode
    case assetNotLoaded
    case operationFailed(String)

    var errorDescription: String? {
        switch self {
        case .clipNotFound:
            return "Clip not found"
        case .trackNotFound:
            return "Track not found"
        case .invalidSplitPoint:
            return "Cannot split clip at this point"
        case .trimExceedsSource:
            return "Trim duration exceeds source asset"
        case .wouldOverlap:
            return "Clip would overlap another clip"
        case .invalidSpeed:
            return "Speed must be between 0.1x and 16.0x"
        case .slipExceedsAsset:
            return "Slip would exceed asset boundaries"
        case .alreadyInMultiClipMode:
            return "Already in multi-clip mode"
        case .alreadyInSingleAssetMode:
            return "Already in single-asset mode"
        case .assetNotLoaded:
            return "Asset not loaded"
        case .operationFailed(let message):
            return "Operation failed: \(message)"
        }
    }
}