import Cocoa
import Combine

/// Dedicated library management interface for presets
@MainActor
final class PresetManagerWindow: NSWindowController {

    private let library: PresetLibrary
    private var previewRenderer = PresetPreviewRenderer()
    private var cancellables = Set<AnyCancellable>()

    /// Currently selected folder
    @Published var selectedFolder: String = "All"

    /// Presets currently displayed
    @Published var displayedPresets: [TransitionPreset] = []

    /// Outline view for folders
    private let outlineView: NSOutlineView = {
        let outline = NSOutlineView()
        outline.headerView = nil
        outline.translatesAutoresizingMaskIntoConstraints = false
        return outline
    }()

    /// Scroll view for outline
    private let outlineScrollView: NSScrollView = {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.borderType = .lineBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        return scroll
    }()

    /// Collection view for presets
    private let collectionView: NSCollectionView = {
        let layout = NSCollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.itemSize = NSSize(width: 200, height: 150)
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 12

        let collection = NSCollectionView()
        collection.collectionViewLayout = layout
        collection.translatesAutoresizingMaskIntoConstraints = false
        return collection
    }()

    /// Scroll view for collection
    private let collectionScrollView: NSScrollView = {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.borderType = .lineBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        return scroll
    }()

    /// Status label
    private let statusLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    init(library: PresetLibrary = PresetLibrary()) {
        self.library = library
        super.init(window: nil)

        // Load custom presets
        try? library.loadCustomPresets()

        setupWindow()
        setupUI()
        setupBindings()
        updateDisplayedPresets()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Preset Library"
        window.center()
        self.window = window
    }

    private func setupUI() {
        guard let window = self.window else { return }

        // Create toolbar
        let toolbar = NSToolbar(identifier: NSToolbar.Identifier("PresetManagerToolbar"))
        toolbar.delegate = self
        window.toolbar = toolbar

        // Split view
        let splitView = NSSplitView()
        splitView.translatesAutoresizingMaskIntoConstraints = false
        splitView.dividerStyle = .thin
        window.contentView = splitView

        // Sidebar
        outlineScrollView.documentView = outlineView
        splitView.addArrangedSubview(outlineScrollView)

        // Main content
        collectionScrollView.documentView = collectionView
        splitView.addArrangedSubview(collectionScrollView)

        // Status bar
        let statusBar = NSView()
        statusBar.translatesAutoresizingMaskIntoConstraints = false
        statusBar.wantsLayer = true
        statusBar.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        window.contentView?.addSubview(statusBar)

        statusBar.addSubview(statusLabel)

        // Constraints
        NSLayoutConstraint.activate([
            splitView.topAnchor.constraint(equalTo: window.contentView!.topAnchor),
            splitView.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor),
            splitView.bottomAnchor.constraint(equalTo: statusBar.topAnchor),

            statusBar.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor),
            statusBar.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor),
            statusBar.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor),
            statusBar.heightAnchor.constraint(equalToConstant: 24),

            statusLabel.leadingAnchor.constraint(equalTo: statusBar.leadingAnchor, constant: 12),
            statusLabel.centerYAnchor.constraint(equalTo: statusBar.centerYAnchor)
        ])

        // Setup outline view
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.reloadData()

        // Setup collection view
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(PresetCardItem.self, forItemWithIdentifier: NSUserInterfaceItemIdentifier("PresetCardItem"))
    }

    private func setupBindings() {
        $selectedFolder
            .sink { [weak self] _ in
                self?.updateDisplayedPresets()
            }
            .store(in: &cancellables)

        $displayedPresets
            .sink { [weak self] _ in
                self?.collectionView.reloadData()
                self?.updateStatusLabel()
            }
            .store(in: &cancellables)
    }

    private func updateDisplayedPresets() {
        displayedPresets = library.presetsInFolder(selectedFolder)
        previewRenderer = PresetPreviewRenderer() // Clear cache
    }

    private func updateStatusLabel() {
        let total = library.allPresets.count
        let favorites = library.favoritePresets().count
        statusLabel.stringValue = "Presets: \(total) total (\(favorites) favorites)"
    }

    /// Apply preset to selected clips
    func applyPreset(_ preset: TransitionPreset) {
        // Post notification for inspector to handle
        NotificationCenter.default.post(
            name: .applyPresetToSelection,
            object: self,
            userInfo: ["preset": preset]
        )
    }

    /// Show import dialog
    func importPresets() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false

        panel.beginSheetModal(for: window!) { response in
            if response == .OK {
                for url in panel.urls {
                    try? self.library.importPreset(from: url)
                }
                self.updateDisplayedPresets()
                self.outlineView.reloadData()
            }
        }
    }

    /// Export selected presets
    func exportSelectedPresets() {
        guard collectionView.selectionIndexes.count > 0 else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "preset.json"

        panel.beginSheetModal(for: window!) { response in
            if response == .OK, let url = panel.url {
                // Export first selected preset
                if let index = self.collectionView.selectionIndexes.first {
                    let preset = self.displayedPresets[index]
                    try? self.library.exportPreset(preset, to: url)
                }
            }
        }
    }

    /// Create new folder
    func createFolder(name: String) {
        library.folders.insert(name)
        outlineView.reloadData()
    }
}

// MARK: - NSToolbarDelegate

extension PresetManagerWindow: NSToolbarDelegate {
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)

        switch itemIdentifier.rawValue {
        case "NewFolder":
            toolbarItem.label = "New Folder"
            toolbarItem.paletteLabel = "New Folder"
            toolbarItem.action = #selector(newFolderClicked)
            toolbarItem.target = self
            toolbarItem.image = NSImage(systemSymbolName: "folder.badge.plus", accessibilityDescription: nil)
        case "Import":
            toolbarItem.label = "Import"
            toolbarItem.paletteLabel = "Import"
            toolbarItem.action = #selector(importClicked)
            toolbarItem.target = self
            toolbarItem.image = NSImage(systemSymbolName: "square.and.arrow.down", accessibilityDescription: nil)
        case "Export":
            toolbarItem.label = "Export Selected"
            toolbarItem.paletteLabel = "Export Selected"
            toolbarItem.action = #selector(exportClicked)
            toolbarItem.target = self
            toolbarItem.image = NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: nil)
        default:
            return nil
        }

        return toolbarItem
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            NSToolbarItem.Identifier("NewFolder"),
            NSToolbarItem.Identifier("Import"),
            NSToolbarItem.Identifier("Export"),
            NSToolbarItem.Identifier.flexibleSpace,
            NSToolbarItem.Identifier.printItem
        ]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            NSToolbarItem.Identifier("NewFolder"),
            NSToolbarItem.Identifier("Import"),
            NSToolbarItem.Identifier("Export"),
            NSToolbarItem.Identifier.flexibleSpace
        ]
    }

    @objc private func newFolderClicked() {
        let alert = NSAlert()
        alert.messageText = "New Folder"
        alert.informativeText = "Enter a name for the new folder:"
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.placeholderString = "Folder Name"
        alert.accessoryView = input

        alert.beginSheetModal(for: window!) { [weak self] response in
            if response == .OK {
                let folderName = input.stringValue.trimmingCharacters(in: .whitespaces)
                if !folderName.isEmpty {
                    self?.createFolder(name: folderName)
                }
            }
        }
    }

    @objc private func importClicked() {
        importPresets()
    }

    @objc private func exportClicked() {
        exportSelectedPresets()
    }
}

// MARK: - NSOutlineViewDataSource

extension PresetManagerWindow: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return library.folders.count + 2 // +2 for "All" and "Favorites"
        }
        return 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            if index == 0 {
                return "All"
            } else if index == 1 {
                return "Favorites"
            } else {
                let folderIndex = index - 2
                return Array(library.folders).sorted()[folderIndex]
            }
        }
        return ""
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return false
    }
}

// MARK: - NSOutlineViewDelegate

extension PresetManagerWindow: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let text = item as? String ?? ""
        let cell = NSTableCellView()
        let textField = NSTextField(labelWithString: text)
        textField.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(textField)
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        return cell
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        if let selected = outlineView.selectedRow as? Int {
            let item = outlineView.item(atRow: selected) as? String ?? "All"
            selectedFolder = item
        }
    }
}

// MARK: - NSCollectionViewDataSource

extension PresetManagerWindow: NSCollectionViewDataSource {
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return displayedPresets.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(
            withIdentifier: NSUserInterfaceItemIdentifier("PresetCardItem"),
            for: indexPath
        ) as! PresetCardItem

        let preset = displayedPresets[indexPath.item]
        let thumbnail = previewRenderer.thumbnail(for: preset, storage: TransitionPresetStorage())
        item.configure(preset: preset, thumbnail: thumbnail)

        item.onTap = { [weak self] in
            self?.applyPreset(preset)
        }

        return item
    }
}

// MARK: - NSCollectionViewDelegateFlowLayout

extension PresetManagerWindow: NSCollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        // Handle selection if needed
    }
}

// MARK: - PresetCardItem

class PresetCardItem: NSCollectionViewItem {
    var onTap: (() -> Void)?

    func configure(preset: TransitionPreset, thumbnail: CIImage?) {
        // Custom view will be configured by the collection view
        if let cardView = view as? PresetCardView {
            cardView.configure(preset: preset, thumbnail: thumbnail)
            cardView.onTap = onTap
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let applyPresetToSelection = Notification.Name("applyPresetToSelection")
}
