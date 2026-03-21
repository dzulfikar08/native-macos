import Foundation
import AppKit
import CoreImage
import CoreMedia

/// Renders animated preview of transition effect
@MainActor
final class TransitionPreviewView: NSView {
    private let transition: TransitionClip
    private let renderer: TransitionPreviewRenderer
    private let frameSize: CGSize
    private let leadingFrame: CIImage
    private let trailingFrame: CIImage

    // Animation state
    private var animationTimer: Timer?
    private(set) var currentProgress: Double = 0.0
    private var animationDirection: AnimationDirection = .forward
    private(set) var isPlaying: Bool = true
    private(set) var isLooping: Bool = true

    // UI components
    fileprivate(set) var imageView: NSImageView!
    fileprivate(set) var playPauseButton: NSButton!
    fileprivate(set) var progressSlider: NSSlider!
    fileprivate(set) var loopCheckbox: NSButton!

    private enum AnimationDirection {
        case forward    // 0.0 → 1.0
        case backward   // 1.0 → 0.0
    }

    init(
        transition: TransitionClip,
        renderer: TransitionPreviewRenderer,
        frameSize: CGSize = CGSize(width: 640, height: 360)
    ) {
        self.transition = transition
        self.renderer = renderer
        self.frameSize = frameSize
        self.leadingFrame = PreviewFrameGenerator.makeLeadingFrame(size: frameSize)
        self.trailingFrame = PreviewFrameGenerator.makeTrailingFrame(size: frameSize)
        super.init(frame: .zero)
        setupUI()
        startAnimation()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - UI Setup

    private func setupUI() {
        wantsLayer = true

        // Image view for preview
        imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.backgroundColor = NSColor.black.cgColor
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        // Controls container
        let controlsStack = NSStackView()
        controlsStack.orientation = .horizontal
        controlsStack.spacing = 12
        controlsStack.translatesAutoresizingMaskIntoConstraints = false

        // Play/Pause button
        playPauseButton = NSButton()
        playPauseButton.title = "Pause"
        playPauseButton.bezelStyle = .rounded
        playPauseButton.target = self
        playPauseButton.action = #selector(togglePlayPause)
        controlsStack.addArrangedSubview(playPauseButton)

        // Progress slider
        progressSlider = NSSlider()
        progressSlider.minValue = 0
        progressSlider.maxValue = 1
        progressSlider.doubleValue = 0
        progressSlider.target = self
        progressSlider.action = #selector(scrubProgress(_:))
        controlsStack.addArrangedSubview(progressSlider)

        // Loop checkbox
        loopCheckbox = NSButton()
        loopCheckbox.title = "Loop"
        loopCheckbox.setButtonType(.switch)
        loopCheckbox.state = .on
        loopCheckbox.target = self
        loopCheckbox.action = #selector(toggleLoop)
        controlsStack.addArrangedSubview(loopCheckbox)

        addSubview(controlsStack)

        // Layout
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.heightAnchor.constraint(equalTo: heightAnchor, constant: -40),

            controlsStack.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 8),
            controlsStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            controlsStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            controlsStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])

        // Initial render
        renderFrame(at: currentProgress)
    }

    // MARK: - Animation

    private func startAnimation() {
        guard isPlaying else { return }

        // 30fps = ~33.33ms per frame
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateAnimation()
            }
        }
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    private func updateAnimation() {
        guard isPlaying else { return }

        let progressStep: Double = 0.02 // 2% per frame at 30fps

        switch animationDirection {
        case .forward:
            currentProgress += progressStep
            if currentProgress >= 1.0 {
                currentProgress = 1.0
                if isLooping {
                    animationDirection = .backward
                } else {
                    isPlaying = false
                    Task { @MainActor in
                        self.stopAnimation()
                        self.updateButtonStates()
                    }
                }
            }
        case .backward:
            currentProgress -= progressStep
            if currentProgress <= 0.0 {
                currentProgress = 0.0
                if isLooping {
                    animationDirection = .forward
                } else {
                    isPlaying = false
                    Task { @MainActor in
                        self.stopAnimation()
                        self.updateButtonStates()
                    }
                }
            }
        }

        progressSlider.doubleValue = currentProgress
        renderFrame(at: currentProgress)
    }

    private func renderFrame(at progress: Double) {
        // Apply transition between test frames
        guard let rendered = renderer.applyTransition(
            from: leadingFrame,
            to: trailingFrame,
            transition: transition,
            progress: progress
        ) else {
            // Show error placeholder if rendering not supported
            imageView.image = createErrorPlaceholder()
            return
        }

        // Convert CIImage to NSImage
        let rep = NSCIImageRep(ciImage: rendered)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        imageView.image = nsImage
    }

    private func createErrorPlaceholder() -> NSImage {
        let size = frameSize
        let image = NSImage(size: size)
        image.lockFocus()

        let text = "Transition type not yet supported"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24),
            .foregroundColor: NSColor.white
        ]

        let textSize = text.size(withAttributes: attrs)
        let textPoint = CGPoint(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2
        )

        text.draw(at: textPoint, withAttributes: attrs)
        image.unlockFocus()

        return image
    }

    // MARK: - Actions

    @objc private func togglePlayPause() {
        isPlaying.toggle()

        if isPlaying {
            startAnimation()
        } else {
            stopAnimation()
        }

        updateButtonStates()
    }

    @objc private func scrubProgress(_ sender: NSSlider) {
        currentProgress = sender.doubleValue
        renderFrame(at: currentProgress)
    }

    @objc private func toggleLoop() {
        isLooping = (loopCheckbox.state == .on)
    }

    private func updateButtonStates() {
        playPauseButton.title = isPlaying ? "Pause" : "Play"
    }

    // MARK: - Public API

    /// Update preview when transition parameters change
    func updateTransition(_ updatedTransition: TransitionClip) {
        // Note: In real implementation, would replace stored transition
        // For now, just re-render at current progress
        renderFrame(at: currentProgress)
    }

    // MARK: - Cleanup

    deinit {
        // Timer cleanup must happen synchronously in deinit
        // We can't call stopAnimation() because it's @MainActor
        // The timer will be cleaned up when the view is deallocated
    }
}
