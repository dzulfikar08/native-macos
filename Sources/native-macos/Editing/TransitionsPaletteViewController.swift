import AppKit
import Foundation

@MainActor
final class TransitionsPaletteViewController: NSViewController {
    private var editorState: EditorState

    // UI components
    fileprivate var outlineView: NSOutlineView!
    private var scrollView: NSScrollView!

    // Drag pasteboard type
    enum DragPasteboardType {
        static let transitionType = NSPasteboard.PasteboardType("com.openscreen.transitionType")
    }

    // Data model
    private var items: [Any] = []

    init(editorState: EditorState) {
        self.editorState = editorState
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadData()
    }

    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        // Create scroll view
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        // Create outline view
        outlineView = NSOutlineView()
        outlineView.delegate = self
        outlineView.dataSource = self
        outlineView.headerView = nil
        outlineView.usesAlternatingRowBackgroundColors = false
        outlineView.allowsMultipleSelection = false

        scrollView.documentView = outlineView
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Register as drag source
        outlineView.setDraggingSourceOperationMask(.copy, forLocal: false)
    }

    private func loadData() {
        // Build hierarchical data: categories -> presets
        var result: [Any] = []

        for category in TransitionCategory.allCases {
            result.append(category)

            let presetsInCategory = BuiltInPresets.presets.filter {
                $0.transitionType.category == category
            }

            for preset in presetsInCategory {
                result.append(preset)
            }
        }

        items = result
        outlineView.reloadData()
    }
}

// MARK: - NSOutlineViewDataSource

extension TransitionsPaletteViewController: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            // Root level - return categories
            return TransitionCategory.allCases.count
        } else if let category = item as? TransitionCategory {
            // Return presets in category
            return BuiltInPresets.presets.filter {
                $0.transitionType.category == category
            }.count
        }
        return 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil {
            // Return category at index
            return TransitionCategory.allCases[index]
        } else if let category = item as? TransitionCategory {
            // Return preset at index
            let presets = BuiltInPresets.presets.filter {
                $0.transitionType.category == category
            }
            return presets[index]
        }
        return ""
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return item is TransitionCategory
    }
}

// MARK: - NSOutlineViewDelegate

extension TransitionsPaletteViewController: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        if let category = item as? TransitionCategory {
            let cellView = NSTableCellView()
            let textField = NSTextField()
            textField.stringValue = category.rawValue
            textField.isEditable = false
            textField.isBordered = false
            textField.backgroundColor = .clear
            textField.font = NSFont.boldSystemFont(ofSize: 13)
            textField.translatesAutoresizingMaskIntoConstraints = false
            cellView.addSubview(textField)

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])

            return cellView
        } else if let preset = item as? TransitionPreset {
            let cellView = NSTableCellView()
            let textField = NSTextField()
            textField.stringValue = preset.name
            textField.isEditable = false
            textField.isBordered = false
            textField.backgroundColor = .clear
            textField.translatesAutoresizingMaskIntoConstraints = false
            cellView.addSubview(textField)

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 20),
                textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
            ])

            return cellView
        }

        return nil
    }

    // MARK: - Drag Source

    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any, index: Int) -> NSPasteboardWriting? {
        guard let preset = item as? TransitionPreset else {
            return nil
        }

        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(
            preset.transitionType.rawValue,
            forType: TransitionsPaletteViewController.DragPasteboardType.transitionType
        )

        return pasteboardItem
    }
}

// MARK: - TransitionCategory Extension

extension TransitionCategory {
    static var allCases: [TransitionCategory] {
        [.basic, .directional, .shape]
    }
}
