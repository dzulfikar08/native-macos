import AppKit

/// Protocol for playback control delegate callbacks
@MainActor
protocol PlaybackControlsDelegate: AnyObject {
    /// Called when play is triggered
    func playbackControlsDidPlay(_ controls: PlaybackControls)

    /// Called when pause is triggered
    func playbackControlsDidPause(_ controls: PlaybackControls)

    /// Called when stop is triggered
    func playbackControlsDidStop(_ controls: PlaybackControls)

    /// Called when seeking is performed
    func playbackControls(_ controls: PlaybackControls, didSeekBy amount: Double)

    /// Called when playback position changes
    func playbackControls(_ controls: PlaybackControls, didUpdatePosition position: Double)

    /// Called for frame stepping
    func playbackControlsDidStepForward(_ controls: PlaybackControls)

    /// Called for frame stepping
    func playbackControlsDidStepBackward(_ controls: PlaybackControls)

    /// Called for loop control
    func playbackControlsSetLoopStart(_ controls: PlaybackControls)

    /// Called for loop control
    func playbackControlsSetLoopEnd(_ controls: PlaybackControls)

    /// Called for loop control
    func playbackControlsClearLoop(_ controls: PlaybackControls)
}

/// Playback controls view for managing video playback
@MainActor
final class PlaybackControls: NSView {
    weak var delegate: PlaybackControlsDelegate?

    private var playPauseButton: NSButton!
    private var stopButton: NSButton!
    private var previousFrameButton: NSButton!
    private var nextFrameButton: NSButton!
    private var seekForwardButton: NSButton!
    private var seekBackwardButton: NSButton!
    private var loopStartButton: NSButton!
    private var loopEndButton: NSButton!
    private var clearLoopButton: NSButton!
    private var loopDropdown: NSPopUpButton!
    private var positionSlider: NSSlider!

    /// Current playback state
    private(set) var isPlaying = false

    /// Current playback position in seconds
    private(set) var playbackPosition: Double = 0.0

    /// Playback speed multiplier
    private(set) var playbackSpeed: Double = 1.0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        // Create play/pause button
        playPauseButton = NSButton(title: "Play", target: self, action: #selector(playPause))
        playPauseButton.bezelStyle = .rounded
        playPauseButton.translatesAutoresizingMaskIntoConstraints = false

        // Create stop button
        stopButton = NSButton(title: "Stop", target: self, action: #selector(stop))
        stopButton.bezelStyle = .rounded
        stopButton.translatesAutoresizingMaskIntoConstraints = false

        // Create previous frame button (⏮)
        previousFrameButton = NSButton(title: "⏮", target: self, action: #selector(previousFrame))
        previousFrameButton.bezelStyle = .rounded
        previousFrameButton.translatesAutoresizingMaskIntoConstraints = false
        previousFrameButton.toolTip = "Previous Frame (⏮) - Cmd+↑"

        // Create next frame button (⏭)
        nextFrameButton = NSButton(title: "⏭", target: self, action: #selector(nextFrame))
        nextFrameButton.bezelStyle = .rounded
        nextFrameButton.translatesAutoresizingMaskIntoConstraints = false
        nextFrameButton.toolTip = "Next Frame (⏭) - Cmd+↓"

        // Create seek backward button
        seekBackwardButton = NSButton(title: "-5s", target: self, action: #selector(seekBackward))
        seekBackwardButton.bezelStyle = .rounded
        seekBackwardButton.translatesAutoresizingMaskIntoConstraints = false

        // Create seek forward button
        seekForwardButton = NSButton(title: "+5s", target: self, action: #selector(seekForward))
        seekForwardButton.bezelStyle = .rounded
        seekForwardButton.translatesAutoresizingMaskIntoConstraints = false

        // Create loop control buttons
        loopStartButton = NSButton(title: "Loop Start", target: self, action: #selector(setLoopStart))
        loopStartButton.bezelStyle = .rounded
        loopStartButton.translatesAutoresizingMaskIntoConstraints = false
        loopStartButton.toolTip = "Set Loop Start (Cmd+[)"

        loopEndButton = NSButton(title: "Loop End", target: self, action: #selector(setLoopEnd))
        loopEndButton.bezelStyle = .rounded
        loopEndButton.translatesAutoresizingMaskIntoConstraints = false
        loopEndButton.toolTip = "Set Loop End (Cmd+])"

        clearLoopButton = NSButton(title: "Clear Loop", target: self, action: #selector(clearLoop))
        clearLoopButton.bezelStyle = .rounded
        clearLoopButton.translatesAutoresizingMaskIntoConstraints = false
        clearLoopButton.toolTip = "Clear Loop (Cmd+L)"

        // Create loop dropdown
        loopDropdown = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 120, height: 30), pullsDown: false)
        setupLoopDropdown()
        loopDropdown.translatesAutoresizingMaskIntoConstraints = false

        // Create position slider
        positionSlider = NSSlider(value: 0, minValue: 0, maxValue: 100, target: self, action: #selector(sliderChanged))
        positionSlider.translatesAutoresizingMaskIntoConstraints = false

        // Add subviews
        addSubview(seekBackwardButton)
        addSubview(stopButton)
        addSubview(previousFrameButton)
        addSubview(nextFrameButton)
        addSubview(playPauseButton)
        addSubview(seekForwardButton)
        addSubview(loopStartButton)
        addSubview(loopEndButton)
        addSubview(clearLoopButton)
        addSubview(loopDropdown)
        addSubview(positionSlider)

        // Layout constraints
        NSLayoutConstraint.activate([
            seekBackwardButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            seekBackwardButton.centerYAnchor.constraint(equalTo: centerYAnchor),

            stopButton.leadingAnchor.constraint(equalTo: seekBackwardButton.trailingAnchor, constant: 8),
            stopButton.centerYAnchor.constraint(equalTo: centerYAnchor),

            previousFrameButton.leadingAnchor.constraint(equalTo: stopButton.trailingAnchor, constant: 8),
            previousFrameButton.centerYAnchor.constraint(equalTo: centerYAnchor),

            nextFrameButton.leadingAnchor.constraint(equalTo: previousFrameButton.trailingAnchor, constant: 4),
            nextFrameButton.centerYAnchor.constraint(equalTo: centerYAnchor),

            playPauseButton.leadingAnchor.constraint(equalTo: nextFrameButton.trailingAnchor, constant: 8),
            playPauseButton.centerYAnchor.constraint(equalTo: centerYAnchor),

            seekForwardButton.leadingAnchor.constraint(equalTo: playPauseButton.trailingAnchor, constant: 8),
            seekForwardButton.centerYAnchor.constraint(equalTo: centerYAnchor),

            loopStartButton.leadingAnchor.constraint(equalTo: seekForwardButton.trailingAnchor, constant: 8),
            loopStartButton.centerYAnchor.constraint(equalTo: centerYAnchor),

            loopEndButton.leadingAnchor.constraint(equalTo: loopStartButton.trailingAnchor, constant: 4),
            loopEndButton.centerYAnchor.constraint(equalTo: centerYAnchor),

            clearLoopButton.leadingAnchor.constraint(equalTo: loopEndButton.trailingAnchor, constant: 4),
            clearLoopButton.centerYAnchor.constraint(equalTo: centerYAnchor),

            loopDropdown.leadingAnchor.constraint(equalTo: clearLoopButton.trailingAnchor, constant: 8),
            loopDropdown.centerYAnchor.constraint(equalTo: centerYAnchor),

            positionSlider.leadingAnchor.constraint(equalTo: loopDropdown.trailingAnchor, constant: 8),
            positionSlider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            positionSlider.centerYAnchor.constraint(equalTo: centerYAnchor),
            positionSlider.widthAnchor.constraint(greaterThanOrEqualToConstant: 200)
        ])
    }

    private func setupLoopDropdown() {
        loopDropdown.addItems(withTitles: [
            "No Loop",
            "Selected Region",
            "Entire Video",
            "Custom Start→End"
        ])
        loopDropdown.target = self
        loopDropdown.action = #selector(loopDropdownChanged)
    }

    // MARK: - Actions

    @objc func play(_ sender: Any?) {
        isPlaying = true
        playPauseButton.title = "Pause"
        delegate?.playbackControlsDidPlay(self)
    }

    @objc func pause(_ sender: Any?) {
        isPlaying = false
        playPauseButton.title = "Play"
        delegate?.playbackControlsDidPause(self)
    }

    @objc func playPause(_ sender: Any?) {
        if isPlaying {
            pause(sender)
        } else {
            play(sender)
        }
    }

    @objc func stop(_ sender: Any?) {
        isPlaying = false
        playbackPosition = 0.0
        playPauseButton.title = "Play"
        positionSlider.doubleValue = 0.0
        delegate?.playbackControlsDidStop(self)
    }

    @objc func seekForward(_ sender: Any?) {
        let seekAmount: Double = 5.0 * playbackSpeed
        playbackPosition += seekAmount
        positionSlider.doubleValue = playbackPosition
        delegate?.playbackControls(self, didSeekBy: seekAmount)
    }

    @objc func seekBackward(_ sender: Any?) {
        let seekAmount: Double = -5.0 * playbackSpeed
        playbackPosition = max(0, playbackPosition + seekAmount)
        positionSlider.doubleValue = playbackPosition
        delegate?.playbackControls(self, didSeekBy: seekAmount)
    }

    @objc func sliderChanged(_ sender: NSSlider) {
        playbackPosition = sender.doubleValue
        delegate?.playbackControls(self, didUpdatePosition: playbackPosition)
    }

    @objc func previousFrame(_ sender: Any?) {
        delegate?.playbackControlsDidStepBackward(self)
    }

    @objc func nextFrame(_ sender: Any?) {
        delegate?.playbackControlsDidStepForward(self)
    }

    @objc func setLoopStart(_ sender: Any?) {
        delegate?.playbackControlsSetLoopStart(self)
    }

    @objc func setLoopEnd(_ sender: Any?) {
        delegate?.playbackControlsSetLoopEnd(self)
    }

    @objc func clearLoop(_ sender: Any?) {
        delegate?.playbackControlsClearLoop(self)
    }

    @objc func loopDropdownChanged(_ sender: NSPopUpButton) {
        // Handle loop dropdown selection
        let selectedIndex = sender.indexOfSelectedItem
        switch selectedIndex {
        case 0: // No Loop
            delegate?.playbackControlsClearLoop(self)
        case 1: // Selected Region
            delegate?.playbackControlsSetLoopStart(self)
            delegate?.playbackControlsSetLoopEnd(self)
        case 2: // Entire Video
            // Could set loop to entire duration
            print("Loop entire video")
        case 3: // Custom Start→End
            // Could open dialog for custom loop points
            print("Set custom loop points")
        default:
            break
        }
    }

    // MARK: - Public Methods

    /// Update playback position (called during playback)
    func updatePosition(to position: Double) {
        playbackPosition = position
        positionSlider.doubleValue = position
        delegate?.playbackControls(self, didUpdatePosition: position)
    }

    /// Update maximum position (e.g., video duration)
    func updateMaxPosition(_ maxPosition: Double) {
        positionSlider.maxValue = maxPosition
    }

    /// Update button states
    func updatePlayPauseButton() {
        playPauseButton.title = isPlaying ? "Pause" : "Play"
    }

    // MARK: - Keyboard Shortcuts

    override func keyDown(with event: NSEvent) {
        // Handle frame step keyboard shortcuts
        if event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "↑":
                // Cmd+Up for previous frame
                previousFrame(self)
                return
            case "↓":
                // Cmd+Down for next frame
                nextFrame(self)
                return
            case "[":
                // Cmd+[ for loop start
                setLoopStart(self)
                return
            case "]":
                // Cmd+] for loop end
                setLoopEnd(self)
                return
            case "l":
                // Cmd+L for clear loop
                clearLoop(self)
                return
            default:
                break
            }
        }

        // Handle other shortcuts
        super.keyDown(with: event)
    }
}
