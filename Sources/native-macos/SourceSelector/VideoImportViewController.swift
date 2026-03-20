import Cocoa
import AVFoundation

@MainActor
final class VideoImportViewController: NSViewController {

    // MARK: - Properties

    private var recentFiles: [URL] = []
    private var selectedURL: URL?
    private var videoMetadata: VideoMetadata?
    private var thumbnailCache: [URL: NSImage] = [:]
    private let maxCacheSize = 50

    var onVideoSelected: ((URL) -> Void)?

    // MARK: - UI Components

    private lazy var scrollView: NSScrollView = {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
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

    private lazy var browseButton: NSButton = {
        let button = NSButton()
        button.title = "Browse Files..."
        button.bezelStyle = .rounded
        button.controlSize = .large
        button.target = self
        button.action = #selector(browseButtonClicked)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var metadataPanel: NSView = {
        let panel = NSView()
        panel.wantsLayer = true
        panel.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        panel.layer?.cornerRadius = 8
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.isHidden = true
        return panel
    }()

    private lazy var metadataTitleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "Video Information")
        label.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var metadataInfoLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.lineBreakMode = .byWordWrapping
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Drag Drop View

    private lazy var dragDropView: DragDropView = {
        let view = DragDropView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.onFileDropped = { [weak self] url in
            self?.selectVideo(at: url)
        }
        return view
    }()

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        loadRecentFiles()
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        // Add drag drop view as background
        view.addSubview(dragDropView)
        dragDropView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        dragDropView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        dragDropView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        dragDropView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true

        // Add scroll view
        view.addSubview(scrollView)
        scrollView.documentView = stackView

        // Add browse button
        view.addSubview(browseButton)

        // Add metadata panel
        view.addSubview(metadataPanel)
        metadataPanel.addSubview(metadataTitleLabel)
        metadataPanel.addSubview(metadataInfoLabel)

        // Layout constraints
        NSLayoutConstraint.activate([
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: browseButton.topAnchor, constant: -20),

            // Browse button
            browseButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            browseButton.bottomAnchor.constraint(equalTo: metadataPanel.topAnchor, constant: -20),

            // Metadata panel
            metadataPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            metadataPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            metadataPanel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            metadataPanel.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),

            // Metadata labels
            metadataTitleLabel.topAnchor.constraint(equalTo: metadataPanel.topAnchor, constant: 12),
            metadataTitleLabel.leadingAnchor.constraint(equalTo: metadataPanel.leadingAnchor, constant: 12),
            metadataTitleLabel.trailingAnchor.constraint(equalTo: metadataPanel.trailingAnchor, constant: -12),

            metadataInfoLabel.topAnchor.constraint(equalTo: metadataTitleLabel.bottomAnchor, constant: 8),
            metadataInfoLabel.leadingAnchor.constraint(equalTo: metadataPanel.leadingAnchor, constant: 12),
            metadataInfoLabel.trailingAnchor.constraint(equalTo: metadataPanel.trailingAnchor, constant: -12),
            metadataInfoLabel.bottomAnchor.constraint(lessThanOrEqualTo: metadataPanel.bottomAnchor, constant: -12)
        ])

        // Stack view width constraint
        stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor).isActive = true
    }

    // MARK: - Recent Files

    private func loadRecentFiles() {
        recentFiles.removeAll()

        if let recentURLs = NSDocumentController.shared.recentDocumentURLs as? [URL] {
            recentFiles = Array(recentURLs.prefix(10)).filter { isVideoFile($0) }
        }

        refreshRecentFilesList()
    }

    private func refreshRecentFilesList() {
        // Remove existing items
        for view in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(view)
        }

        guard !recentFiles.isEmpty else {
            let emptyLabel = NSTextField(labelWithString: "No recent video files")
            emptyLabel.alignment = .center
            emptyLabel.textColor = .secondaryLabelColor
            emptyLabel.font = NSFont.systemFont(ofSize: 14)
            emptyLabel.translatesAutoresizingMaskIntoConstraints = false
            stackView.addArrangedSubview(emptyLabel)
            return
        }

        // Add recent file items
        for url in recentFiles {
            let itemView = createRecentFileItem(url: url)
            stackView.addArrangedSubview(itemView)
        }
    }

    private func createRecentFileItem(url: URL) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        container.layer?.cornerRadius = 8
        container.translatesAutoresizingMaskIntoConstraints = false

        // Thumbnail
        let imageView = NSImageView()
        if let cached = thumbnailCache[url] {
            imageView.image = cached
        } else {
            imageView.image = NSImage(systemSymbolName: "video.fill", accessibilityDescription: nil)
            // TODO: Generate actual thumbnail asynchronously
        }
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 6
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.widthAnchor.constraint(equalToConstant: 80).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: 60).isActive = true

        // Info label
        let nameLabel = NSTextField(labelWithString: url.lastPathComponent)
        nameLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        nameLabel.isEditable = false
        nameLabel.isBordered = false
        nameLabel.backgroundColor = .clear
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        let pathLabel = NSTextField(labelWithString: url.deletingLastPathComponent().path)
        pathLabel.font = NSFont.systemFont(ofSize: 11)
        pathLabel.textColor = .secondaryLabelColor
        pathLabel.isEditable = false
        pathLabel.isBordered = false
        pathLabel.backgroundColor = .clear
        pathLabel.lineBreakMode = .byTruncatingMiddle
        pathLabel.translatesAutoresizingMaskIntoConstraints = false

        // Add click handler
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(recentFileClicked(_:)))
        container.addGestureRecognizer(clickGesture)

        container.addSubview(imageView)
        container.addSubview(nameLabel)
        container.addSubview(pathLabel)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            nameLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),

            pathLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            pathLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            pathLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),

            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 80)
        ])

        container.identifier = NSUserInterfaceItemIdentifier(url.absoluteString)

        return container
    }

    // MARK: - Actions

    @objc private func browseButtonClicked() {
        showFileOpenPanel()
    }

    @objc private func recentFileClicked(_ gesture: NSClickGestureRecognizer) {
        guard let container = gesture.view,
              let identifier = container.identifier?.rawValue,
              let url = URL(string: identifier) else {
            return
        }

        selectVideo(at: url)
    }

    // MARK: - File Selection

    private func showFileOpenPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.movie, .audiovisualContent, .quickTimeMovie, .mpeg4Movie, .mpeg]

        guard let window = view.window else { return }
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.selectVideo(at: url)
        }
    }

    private func selectVideo(at url: URL) {
        // Validate file
        let result = VideoValidator.validate(url: url)

        switch result {
        case .success(let metadata):
            selectedURL = url
            videoMetadata = metadata

            // Show metadata panel
            metadataPanel.isHidden = false
            updateMetadataDisplay(metadata)

            // Show import confirmation
            showImportConfirmation()

        case .failure(let error):
            handleValidationError(error)
        }
    }

    private func showImportConfirmation() {
        let alert = NSAlert()
        alert.messageText = "Import Video"
        alert.informativeText = "Import \(selectedURL?.lastPathComponent ?? "this video")?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Import")
        alert.addButton(withTitle: "Cancel")

        guard let window = view.window else { return }
        alert.beginSheetModal(for: window) { [weak self] response in
            if response == .alertFirstButtonReturn {
                self?.confirmImport()
            }
        }
    }

    private func confirmImport() {
        guard let url = selectedURL else {
            return
        }

        onVideoSelected?(url)
    }

    private func handleValidationError(_ error: VideoValidationError) {
        guard let window = view.window else { return }
        let alert = NSAlert()
        alert.messageText = "Cannot Import Video"
        alert.alertStyle = .warning
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: window)
    }

    // MARK: - Metadata Display

    private func updateMetadataDisplay(_ metadata: VideoMetadata) {
        var info = "Duration: \(metadata.durationString)\n"
        info += "Resolution: \(metadata.resolutionString)\n"
        info += "Frame Rate: \(String(format: "%.1f", metadata.frameRate)) fps\n"
        info += "Codec: \(metadata.codec)\n"
        info += "File Size: \(metadata.fileSizeString)"

        if metadata.hasWarnings {
            info += "\n\nWarnings:"
            for warning in metadata.warnings {
                info += "\n• \(warning)"
            }
        }

        metadataInfoLabel.stringValue = info
    }

    // MARK: - Thumbnail Cache Management

    private func cacheThumbnail(_ image: NSImage, for url: URL) {
        // Remove oldest entry if cache is at capacity
        if thumbnailCache.count >= maxCacheSize {
            let oldestKey = thumbnailCache.keys.first
            if let key = oldestKey {
                thumbnailCache.removeValue(forKey: key)
            }
        }
        thumbnailCache[url] = image
    }

    // MARK: - Helpers

    private func isVideoFile(_ url: URL) -> Bool {
        let extensions = ["mp4", "mov", "m4v", "avi", "mkv", "flv", "wmv", "webm", "mpeg", "mpg"]
        return extensions.contains(url.pathExtension.lowercased())
    }
}

// MARK: - Drag Drop View

private class DragDropView: NSView {
    var onFileDropped: ((URL) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        registerForDraggedTypes([.fileURL])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let types = sender.draggingPasteboard.types, types.contains(.fileURL) else {
            return []
        }
        return .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let pasteboard = sender.draggingPasteboard.pasteboardItems,
              let item = pasteboard.first,
              let urlData = item.data(forType: .fileURL),
              let url = URL(dataRepresentation: urlData, relativeTo: nil) else {
            return false
        }

        onFileDropped?(url)
        return true
    }
}
