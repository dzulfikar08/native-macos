import Cocoa
import CoreImage

/// Card component displaying a preset with thumbnail
@MainActor
final class PresetCardView: NSView {

    private let imageView = NSImageView()
    private let favoriteButton = NSButton()
    private let label = NSTextField()
    private var onClick: (() -> Void)?

    var preset: TransitionPreset?
    var thumbnail: CIImage?

    var onTap: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.cornerRadius = 8

        // Image view
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter
        imageView.wantsLayer = true
        imageView.layer?.backgroundColor = NSColor.darkGray.cgColor
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        // Favorite button
        favoriteButton.title = "⭐"
        favoriteButton.isBordered = false
        favoriteButton.focusRingType = .none
        favoriteButton.translatesAutoresizingMaskIntoConstraints = false
        favoriteButton.target = self
        favoriteButton.action = #selector(favoriteClicked)
        addSubview(favoriteButton)

        // Label
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.alignment = .center
        label.maximumNumberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        // Double-click gesture
        let doubleClickGesture = NSClickGestureRecognizer(target: self, action: #selector(doubleClicked))
        doubleClickGesture.numberOfClicksRequired = 2
        addGestureRecognizer(doubleClickGesture)

        // Constraints
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            imageView.heightAnchor.constraint(equalToConstant: 72),

            favoriteButton.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            favoriteButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            favoriteButton.widthAnchor.constraint(equalToConstant: 24),
            favoriteButton.heightAnchor.constraint(equalToConstant: 24),

            label.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 4),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            label.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -4)
        ])
    }

    func configure(preset: TransitionPreset, thumbnail: CIImage?) {
        self.preset = preset
        self.thumbnail = thumbnail
        label.stringValue = preset.name

        // Update favorite button
        updateFavoriteButton()

        // Update thumbnail
        if let thumbnail = thumbnail {
            let rep = NSCIImageRep(ciImage: thumbnail)
            let nsImage = NSImage(size: rep.size)
            nsImage.addRepresentation(rep)
            imageView.image = nsImage
        } else {
            imageView.image = nil
        }
    }

    private func updateFavoriteButton() {
        guard let preset = preset else { return }
        favoriteButton.title = preset.isFavorite ? "⭐" : "☆"
    }

    @objc private func favoriteClicked() {
        onTap?()
        updateFavoriteButton()
    }

    @objc private func doubleClicked() {
        onTap?()
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)

        if event.clickCount == 2 {
            onTap?()
        }
    }
}
