import Foundation
import AppKit

/// Keyboard controller for playback control using J, K, L keys
@MainActor
final class JKLController {

    // MARK: - State

    enum State: Equatable {
        case paused
        case playing
        case reverse
    }

    enum JKLKey: Hashable {
        case j
        case k
        case l
        case unknown
    }

    // MARK: - Properties

    private(set) var state: State = .paused

    private var keyPressTimers: [JKLKey: Timer] = [:]
    private var keyHoldStartTime: [JKLKey: Date] = [:]

    private let editorState: EditorState

    // MARK: - Constants

    private struct Acceleration {
        static let initialRate: Float = 1.0
        static let firstAcceleration: Float = 2.0
        static let secondAcceleration: Float = 4.0
        static let firstAccelerationDelay: TimeInterval = 0.5
        static let secondAccelerationDelay: TimeInterval = 1.0
    }

    // MARK: - Initialization

    init(editorState: EditorState) {
        self.editorState = editorState
    }

    // MARK: - Public Methods

    func handleKeyDown(_ key: JKLKey) {
        guard key != .unknown else { return }

        // Cancel any existing timer for this key to restart acceleration
        keyPressTimers[key]?.invalidate()
        keyPressTimers[key] = nil

        // Record hold start time
        keyHoldStartTime[key] = Date()

        // Set up acceleration timer
        setupAccelerationTimer(for: key)

        // Handle key press
        handleKeyPress(key)
    }

    func handleKeyUp(_ key: JKLKey) {
        guard key != .unknown else { return }

        // Cancel acceleration timer
        keyPressTimers[key]?.invalidate()
        keyPressTimers[key] = nil

        // Clear hold start time
        keyHoldStartTime[key] = nil

        // Reset playback rate back to initial
        editorState.playbackRate = Acceleration.initialRate
    }

    func simulateTimePassed(_ timeInterval: TimeInterval) {
        // Check each key to see if it should accelerate
        for key in keyHoldStartTime.keys {
            guard let holdStartTime = keyHoldStartTime[key] else { continue }

            let elapsed = Date().timeIntervalSince(holdStartTime)

            if elapsed >= Acceleration.secondAccelerationDelay {
                // Second acceleration
                if editorState.playbackRate != Acceleration.secondAcceleration {
                    editorState.playbackRate = key == .k ? -Acceleration.secondAcceleration : Acceleration.secondAcceleration
                }
            } else if elapsed >= Acceleration.firstAccelerationDelay {
                // First acceleration
                if editorState.playbackRate != Acceleration.firstAcceleration {
                    editorState.playbackRate = key == .k ? -Acceleration.firstAcceleration : Acceleration.firstAcceleration
                }
            }
        }
    }

    // MARK: - Private Methods

    private func setupAccelerationTimer(for key: JKLKey) {
        let timer = Timer.scheduledTimer(withTimeInterval: Acceleration.secondAccelerationDelay, repeats: false) { [weak self] _ in
            self?.handleAccelerationComplete(for: key)
        }
        keyPressTimers[key] = timer
    }

    private func handleKeyPress(_ key: JKLKey) {
        switch key {
        case .j:
            handleJPress()
        case .k:
            handleKPress()
        case .l:
            handleLPress()
        case .unknown:
            break
        }
    }

    private func handleJPress() {
        switch state {
        case .paused:
            state = .playing
            editorState.isPlaying = true
            editorState.playbackRate = Acceleration.initialRate

        case .playing:
            // Pressing J again toggles to paused
            state = .paused
            editorState.isPlaying = false

        case .reverse:
            // From reverse, pressing J goes to playing
            state = .playing
            editorState.isPlaying = true
            editorState.playbackRate = Acceleration.initialRate
        }
    }

    private func handleKPress() {
        // K can only be effective when playing (either forward or reverse)
        if state == .paused {
            // If paused, K does nothing (or could go to reverse if we implement that logic)
            return
        }

        switch state {
        case .playing:
            // From playing, K goes to reverse
            state = .reverse
            editorState.isPlaying = true
            editorState.playbackRate = -Acceleration.initialRate

        case .reverse:
            // From reverse, K goes back to playing
            state = .playing
            editorState.isPlaying = true
            editorState.playbackRate = Acceleration.initialRate

        case .paused:
            break
        }
    }

    private func handleLPress() {
        // L always pauses
        state = .paused
        editorState.isPlaying = false
        editorState.playbackRate = Acceleration.initialRate
    }

    private func handleAccelerationComplete(for key: JKLKey) {
        // Apply second acceleration if still holding the key
        if keyHoldStartTime[key] != nil {
            let multiplier = key == .k ? -1.0 : 1.0
            editorState.playbackRate = Acceleration.secondAcceleration * Float(multiplier)
        }
    }
}