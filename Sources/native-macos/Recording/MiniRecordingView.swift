import Cocoa
import AVFoundation

/// Mini floating window showing live recording preview
final class MiniRecordingView: NSPanel {
    private static let positionKey = "miniRecordingViewPosition"

    private let mainContentView: NSView
    private let previewLayer: AVCaptureVideoPreviewLayer
    private let stopButton: NSButton
    private let timeLabel: NSTextField

    var onStop: (() -> Void)?

    init() {
        // Create content view
        self.mainContentView = NSView()
        mainContentView.wantsLayer = true
        mainContentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        // Create preview layer
        self.previewLayer = AVCaptureVideoPreviewLayer()
        self.previewLayer.videoGravity = .resizeAspectFill
        self.previewLayer.frame = CGRect(x: 0, y: 30, width: 320, height: 210)

        // Create stop button
        self.stopButton = NSButton()
        self.stopButton.title = "● Stop Recording"
        self.stopButton.bezelStyle = .rounded
        self.stopButton.frame = CGRect(x: 10, y: 0, width: 300, height: 30)

        // Create time label
        self.timeLabel = NSTextField()
        self.timeLabel.stringValue = "00:00"
        self.timeLabel.alignment = .center
        self.timeLabel.isEditable = false
        self.timeLabel.isBordered = false
        self.timeLabel.backgroundColor = .clear
        self.timeLabel.frame = CGRect(x: 220, y: 0, width: 100, height: 30)

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 240),
            styleMask: [.resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.isFloatingPanel = true
        self.level = .floating
        self.title = "Recording"
        self.contentView = mainContentView

        setupUI()
        restorePosition()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        mainContentView.layer?.addSublayer(previewLayer)
        mainContentView.addSubview(stopButton)
        mainContentView.addSubview(timeLabel)

        stopButton.target = self
        stopButton.action = #selector(stopButtonClicked)
    }

    @objc private func stopButtonClicked() {
        onStop?()
    }

    func updatePreview(session: AVCaptureSession) {
        previewLayer.session = session
        previewLayer.frame = mainContentView.bounds
    }

    func updateTime(elapsed: TimeInterval) {
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        timeLabel.stringValue = String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Position Persistence

    func savePosition() {
        let origin = self.frame.origin
        UserDefaults.standard.set([origin.x, origin.y], forKey: Self.positionKey)
    }

    func restorePosition() {
        guard let saved = UserDefaults.standard.array(forKey: Self.positionKey) as? [CGFloat],
              let x = saved.first, let y = saved.last else {
            // Default position: top-right of screen
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                let defaultPos = NSPoint(
                    x: screenFrame.maxX - 340,
                    y: screenFrame.maxY - 260
                )
                self.setFrameOrigin(defaultPos)
            }
            return
        }

        // Validate position is on screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let validatedPos = NSPoint(
                x: max(screenFrame.minX, min(x, screenFrame.maxX - 320)),
                y: max(screenFrame.minY, min(y, screenFrame.maxY - 240))
            )
            self.setFrameOrigin(validatedPos)
        }
    }

    override func close() {
        savePosition()
        super.close()
    }
}
