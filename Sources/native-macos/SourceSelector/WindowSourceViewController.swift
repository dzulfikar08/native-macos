import Cocoa
import CoreGraphics

@MainActor
final class WindowSourceViewController: NSViewController {
    // MARK: - Properties

    private var availableWindows: [WindowDevice] = []
    private var selectedWindows: Set<CGWindowID> = []
    private var settings: WindowRecordingSettings
    private var windowTracker: WindowTracker?
    private var thumbnailUpdateTimer: Timer?

    var onSourceSelected: ((SourceSelection) -> Void)?

    // MARK: - Initialization

    init() {
        self.settings = WindowRecordingSettings()
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - UI Components

    private lazy var scrollView: NSScrollView = {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()

    private lazy var stackView: NSStackView = {
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 8
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private lazy var qualityPopUp: NSPopUpButton = {
        let popup = NSPopUpButton()
        popup.target = self
        popup.action = #selector(qualityPresetChanged)
        for preset in QualityPreset.allCases {
            popup.addItem(withTitle: preset.rawValue.capitalized)
        }
        return popup
    }()

    private lazy var codecPopUp: NSPopUpButton = {
        let popup = NSPopUpButton()
        popup.target = self
        popup.action = #selector(codecChanged)
        for codec in VideoCodec.availableCodecs() {
            popup.addItem(withTitle: codec.rawValue)
        }
        return popup
    }()

    private lazy var startButton: NSButton = {
        let button = NSButton()
        button.title = "Start Recording"
        button.bezelStyle = .rounded
        button.controlSize = .large
        button.target = self
        button.action = #selector(startButtonClicked)
        button.isEnabled = false
        return button
    }()

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        checkPermissions()
        loadWindows()
        startThumbnailUpdates()
        setupWindowTracker()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()

        thumbnailUpdateTimer?.invalidate()
        windowTracker?.stopTracking()
    }

    // MARK: - Permissions

    private func checkPermissions() {
        let status = CGPreflightScreenCaptureAccess()

        if !status {
            showPermissionDeniedAlert()
        }
    }

    private func showPermissionDeniedAlert() {
        availableWindows.removeAll()
        refreshWindowList()

        let alert = NSAlert()
        alert.messageText = "Screen Recording Access Required"
        alert.informativeText = "OpenScreen needs screen recording permission to capture windows. Open System Settings to grant permission."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        view.addSubview(scrollView)
        scrollView.documentView = stackView

        let controlsStack = NSStackView()
        controlsStack.orientation = .horizontal
        controlsStack.spacing = 12
        controlsStack.alignment = .centerY
        controlsStack.translatesAutoresizingMaskIntoConstraints = false

        let qualityLabel = NSTextField(labelWithString: "Quality:")
        let codecLabel = NSTextField(labelWithString: "Codec:")

        controlsStack.addArrangedSubview(qualityLabel)
        controlsStack.addArrangedSubview(qualityPopUp)
        controlsStack.addArrangedSubview(codecLabel)
        controlsStack.addArrangedSubview(codecPopUp)
        controlsStack.addArrangedSubview(startButton)

        view.addSubview(controlsStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: controlsStack.topAnchor, constant: -20),

            controlsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            controlsStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            controlsStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20)
        ])

        stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor).isActive = true
    }

    // MARK: - Window Management

    private func loadWindows() {
        availableWindows = WindowDevice.enumerateWindows()
        refreshWindowList()
    }

    private func refreshWindowList() {
        for view in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(view)
        }

        guard !availableWindows.isEmpty else {
            let emptyLabel = NSTextField(labelWithString: "No windows found.\nOpen an application to see windows here.")
            emptyLabel.alignment = .center
            emptyLabel.textColor = .secondaryLabelColor
            emptyLabel.translatesAutoresizingMaskIntoConstraints = false
            stackView.addArrangedSubview(emptyLabel)
            return
        }

        for window in availableWindows {
            let itemView = createWindowItem(window: window)
            stackView.addArrangedSubview(itemView)
        }
    }

    private func createWindowItem(window: WindowDevice) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        container.layer?.cornerRadius = 8
        container.translatesAutoresizingMaskIntoConstraints = false

        let checkbox = NSButton(checkboxWithTitle: "\(window.name) (\(window.ownerName))", target: self, action: #selector(windowToggled(_:)))
        checkbox.state = .off
        checkbox.identifier = NSUserInterfaceItemIdentifier("\(window.id)")
        checkbox.translatesAutoresizingMaskIntoConstraints = false

        let imageView = NSImageView()
        if let thumbnail = window.thumbnail {
            imageView.image = thumbnail
        } else {
            imageView.image = NSImage(systemSymbolName: "rectangle.on.rectangle", accessibilityDescription: nil)
        }
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.backgroundColor = NSColor.black.cgColor
        imageView.layer?.cornerRadius = 6
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.widthAnchor.constraint(equalToConstant: 240).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: 180).isActive = true

        container.addSubview(checkbox)
        container.addSubview(imageView)

        NSLayoutConstraint.activate([
            checkbox.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            checkbox.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),

            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            imageView.topAnchor.constraint(equalTo: checkbox.bottomAnchor, constant: 8),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),

            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 240)
        ])

        return container
    }

    private func startThumbnailUpdates() {
        thumbnailUpdateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateWindowThumbnails()
            }
        }
    }

    private func updateWindowThumbnails() {
        for index in availableWindows.indices {
            if availableWindows[index].thumbnail == nil {
                availableWindows[index].thumbnail = availableWindows[index].createThumbnail()
            }
        }
        refreshWindowList()
    }

    private func setupWindowTracker() {
        windowTracker = WindowTracker()
        windowTracker?.onWindowStateChanged = { [weak self] windowID, state in
            self?.handleWindowStateChange(windowID, state)
        }
    }

    // MARK: - Actions

    @objc private func windowToggled(_ sender: NSButton) {
        guard let identifier = sender.identifier?.rawValue,
              let windowID = CGWindowID(identifier) else {
            return
        }

        if sender.state == .on {
            guard selectedWindows.count < 4 else {
                sender.state = .off
                return
            }
            selectedWindows.insert(windowID)
        } else {
            selectedWindows.remove(windowID)
        }

        updateCompositingMode()
        startButton.isEnabled = !selectedWindows.isEmpty
    }

    @objc private func qualityPresetChanged() {
        if let title = qualityPopUp.titleOfSelectedItem?.lowercased(),
           let preset = QualityPreset.allCases.first(where: { $0.rawValue.lowercased() == title }) {
            settings.qualityPreset = preset
        }
    }

    @objc private func codecChanged() {
        if let title = codecPopUp.titleOfSelectedItem,
           let codec = VideoCodec.availableCodecs().first(where: { $0.rawValue == title }) {
            settings.codec = codec
        }
    }

    @objc private func startButtonClicked() {
        let selectedWindowDevices = availableWindows.filter { selectedWindows.contains($0.id) }
        settings.selectedWindows = selectedWindowDevices

        let selection = SourceSelection.window(
            windows: selectedWindowDevices,
            settings: settings
        )

        onSourceSelected?(selection)
    }

    private func updateCompositingMode() {
        switch selectedWindows.count {
        case 0...1:
            settings.compositingMode = .single
        case 2:
            settings.compositingMode = .dual(main: 0, overlay: 1)
        case 3:
            settings.compositingMode = .triple(main: 0, p2: 1, p3: 2)
        case 4:
            settings.compositingMode = .quad
        default:
            break
        }
    }

    // MARK: - Window State Handling

    private func handleWindowStateChange(_ windowID: CGWindowID, _ state: WindowTracker.WindowState) {
        switch state {
        case .visible:
            hidePauseNotification()
        case .hidden, .minimized, .onOtherSpace:
            showPauseNotification()
        case .closed:
            // Remove from selection
            selectedWindows.remove(windowID)
            refreshWindowList()
            updateCompositingMode()
            startButton.isEnabled = !selectedWindows.isEmpty
        }
    }

    private func showPauseNotification() {
        // In production, would show overlay banner
        // For now, just log
        print("⏸️ Window unavailable - recording paused")
    }

    private func hidePauseNotification() {
        // In production, would hide overlay banner
        print("▶️ Window available - recording resumed")
    }
}
