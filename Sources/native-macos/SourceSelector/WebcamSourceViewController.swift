import Cocoa
import AVFoundation

@MainActor
final class WebcamSourceViewController: NSViewController {
    // MARK: - Properties

    private var availableCameras: [CameraDevice] = []
    private var selectedCameras: Set<String> = []
    private var lastUsedCamera: String?
    private var settings: WebcamRecordingSettings

    private var previewSessions: [String: AVCaptureSession] = [:]

    var onSourceSelected: ((SourceSelection) -> Void)?

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

    // MARK: - Initialization

    init() {
        // Initialize with default settings
        self.settings = WebcamRecordingSettings()

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        checkPermissions()
    }

    // MARK: - Permissions

    private func checkPermissions() {
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)

        if cameraStatus == .denied || micStatus == .denied {
            showPermissionDeniedAlert()
        } else if cameraStatus == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    if granted {
                        self?.loadCameras()
                    } else {
                        self?.showPermissionDeniedAlert()
                    }
                }
            }
        } else {
            loadCameras()
        }
    }

    private func showPermissionDeniedAlert() {
        // Clear camera list
        availableCameras.removeAll()
        refreshCameraList()

        // Show error message
        let alert = NSAlert()
        alert.messageText = "Camera/Microphone Access Required"
        alert.informativeText = "OpenScreen needs camera and microphone access to record video. Open System Settings to grant permission."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        guard let window = view.window else { return }

        // Begin sheet for alert
        alert.beginSheetModal(for: window) { response in

            if response == .alertFirstButtonReturn {
                // Open System Settings
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    // MARK: - Camera Management

    override func viewWillDisappear() {
        super.viewWillDisappear()

        // Stop previews
        previewSessions.values.forEach { $0.stopRunning() }
        previewSessions.removeAll()
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        // Add scroll view with camera list
        view.addSubview(scrollView)
        scrollView.documentView = stackView

        // Add controls at bottom
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

    // MARK: - Camera Management

    private func loadCameras() {
        availableCameras = CameraDevice.enumerateCameras()
        refreshCameraList()
    }

    private func refreshCameraList() {
        // Remove existing items
        for view in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(view)
        }

        guard !availableCameras.isEmpty else {
            let emptyLabel = NSTextField(labelWithString: "No cameras found.\nConnect a camera and click Refresh.")
            emptyLabel.alignment = .center
            emptyLabel.textColor = .secondaryLabelColor
            stackView.addArrangedSubview(emptyLabel)
            return
        }

        // Add camera items
        for camera in availableCameras {
            let itemView = createCameraItem(camera: camera)
            stackView.addArrangedSubview(itemView)
        }
    }

    private func createCameraItem(camera: CameraDevice) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        container.layer?.cornerRadius = 8
        container.translatesAutoresizingMaskIntoConstraints = false

        // Checkbox
        let checkbox = NSButton(checkboxWithTitle: camera.name, target: self, action: #selector(cameraToggled(_:)))
        checkbox.state = .off
        checkbox.identifier = NSUserInterfaceItemIdentifier(camera.id)
        checkbox.translatesAutoresizingMaskIntoConstraints = false

        // Preview view
        let previewView = NSView()
        previewView.wantsLayer = true
        previewView.layer?.backgroundColor = NSColor.black.cgColor
        previewView.translatesAutoresizingMaskIntoConstraints = false
        previewView.widthAnchor.constraint(equalToConstant: 240).isActive = true
        previewView.heightAnchor.constraint(equalToConstant: 180).isActive = true

        // Start preview for this camera
        startPreview(for: camera, in: previewView)

        container.addSubview(checkbox)
        container.addSubview(previewView)

        NSLayoutConstraint.activate([
            checkbox.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            checkbox.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),

            previewView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            previewView.topAnchor.constraint(equalTo: checkbox.bottomAnchor, constant: 8),
            previewView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            previewView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),

            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 240)
        ])

        return container
    }

    private func startPreview(for camera: CameraDevice, in view: NSView) {
        guard let device = AVCaptureDevice(uniqueID: camera.id) else {
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            let session = AVCaptureSession()
            session.sessionPreset = .low

            guard session.canAddInput(input) else {
                return
            }

            session.addInput(input)

            let output = AVCaptureVideoDataOutput()
            session.addOutput(output)

            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.frame = view.bounds
            previewLayer.videoGravity = .resizeAspectFill
            view.layer?.addSublayer(previewLayer)

            previewSessions[camera.id] = session
            session.startRunning()

        } catch {
            print("⚠️ Failed to start preview for \(camera.name): \(error)")
        }
    }

    // MARK: - Actions

    @objc private func cameraToggled(_ sender: NSButton) {
        guard let cameraID = sender.identifier?.rawValue,
              let camera = availableCameras.first(where: { $0.id == cameraID }) else {
            return
        }

        if sender.state == .on {
            // Check if already at max (4 cameras)
            guard selectedCameras.count < 4 else {
                sender.state = .off
                return
            }
            selectedCameras.insert(cameraID)
            settings.selectedCameras.append(camera)
        } else {
            selectedCameras.remove(cameraID)
            settings.selectedCameras.removeAll { $0.id == cameraID }
        }

        updateCompositingMode()
        startButton.isEnabled = !selectedCameras.isEmpty
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
        guard !settings.selectedCameras.isEmpty else {
            return
        }

        let selection = SourceSelection.webcam(
            cameras: settings.selectedCameras,
            settings: settings
        )

        onSourceSelected?(selection)
    }

    private func updateCompositingMode() {
        switch selectedCameras.count {
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
}
