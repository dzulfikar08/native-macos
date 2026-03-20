import Foundation
import QuartzCore

@MainActor
final class ScrubController {
    var isScrubbing: Bool = false
    private(set) var scrubSpeed: Double = 0.0

    private var dragStartTime: CFTimeInterval = 0
    private var dragStartPosition: CGFloat = 0
    private var lastDragTime: CFTimeInterval = 0
    private var lastDragPosition: CGFloat = 0

    func startScrubbing(at position: CGFloat) {
        isScrubbing = true
        dragStartTime = CACurrentMediaTime()
        dragStartPosition = position
        lastDragTime = dragStartTime
        lastDragPosition = position
        scrubSpeed = 0

        EditorState.shared.isScrubbing = true
    }

    func updateScrub(at position: CGFloat) -> Double {
        guard isScrubbing else { return 0 }

        let velocity = calculateDragVelocity(from: position)
        scrubSpeed = playbackSpeed(for: velocity)

        EditorState.shared.playbackRate = Float(scrubSpeed)

        return scrubSpeed
    }

    func endScrubbing() {
        isScrubbing = false
        scrubSpeed = 0
        EditorState.shared.playbackRate = 0
        EditorState.shared.isScrubbing = false
    }

    private func calculateDragVelocity(from currentDragPosition: CGFloat) -> CGFloat {
        let currentTime = CACurrentMediaTime()
        let timeDelta = currentTime - lastDragTime

        guard timeDelta > 0 else { return 0 }

        let positionDelta = currentDragPosition - lastDragPosition
        let velocity = positionDelta / CGFloat(timeDelta)

        lastDragTime = currentTime
        lastDragPosition = currentDragPosition

        return velocity
    }

    private func playbackSpeed(for velocity: CGFloat) -> Double {
        let absVelocity = abs(velocity)

        let slowThreshold: CGFloat = 50
        let mediumThreshold: CGFloat = 200

        if absVelocity < slowThreshold {
            return 1.0 * sign(velocity)
        } else if absVelocity < mediumThreshold {
            return 0.5 * sign(velocity)
        } else {
            let scrubSpeed = min(absVelocity / 500, 4.0)
            return scrubSpeed * sign(velocity)
        }
    }

    private func sign(_ value: CGFloat) -> Double {
        return value >= 0 ? 1.0 : -1.0
    }
}