import Foundation
import CoreMedia

/// A preset transition configuration
struct TransitionPreset: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    let name: String
    let isBuiltIn: Bool
    let folder: String
    let isFavorite: Bool
    let transitionType: TransitionType
    let parameters: TransitionParameters
    let duration: CMTime

    init(
        id: UUID = UUID(),
        name: String,
        folder: String = "",
        isFavorite: Bool = false,
        isBuiltIn: Bool = false,
        transitionType: TransitionType,
        parameters: TransitionParameters,
        duration: CMTime
    ) {
        self.id = id
        self.name = name
        self.folder = folder
        self.isFavorite = isFavorite
        self.isBuiltIn = isBuiltIn
        self.transitionType = transitionType
        self.parameters = parameters
        self.duration = duration
    }

    /// Creates a TransitionClip from this preset
    func makeTransition(
        leadingClipID: UUID,
        trailingClipID: UUID
    ) -> TransitionClip {
        TransitionClip(
            type: transitionType,
            duration: duration,
            leadingClipID: leadingClipID,
            trailingClipID: trailingClipID,
            parameters: parameters,
            isEnabled: true
        )
    }
}
