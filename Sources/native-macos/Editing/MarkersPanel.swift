import AppKit
import Foundation
import AVFoundation

@MainActor
final class MarkersPanel: NSView, NSTableViewDataSource, NSTableViewDelegate {

    // MARK: - Properties

    private let editorState: EditorState
    private var tableView = NSTableView()
    private var searchField = NSSearchField()
    private var colorFilterButtons: [NSButton] = []
    private var selectedColorFilter: TimelineColor?

    // Data source for filtered markers
    private var dataSource = MarkersDataSource()

    // MARK: - Initialization

    init(editorState: EditorState) {
        self.editorState = editorState
        super.init(frame: .zero)

        setupUI()
        setupConstraints()
        observeEditorState()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - UI Setup

    private func setupUI() {
        // Configure search field
        searchField.placeholderString = "Search markers..."
        searchField.target = self
        searchField.action = #selector(searchFieldDidChange)
        searchField.sendsWholeSearchString = false

        // Configure table view
        tableView.dataSource = self
        tableView.delegate = self
        tableView.headerView = nil
        tableView.style = .plain
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle

        // Add columns
        addTableColumns()

        // Setup color filter buttons
        setupColorFilterButtons()

        // Add subviews
        addSubview(searchField)
        addSubview(tableView)
    }

    private func setupConstraints() {
        searchField.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            searchField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            searchField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            searchField.heightAnchor.constraint(equalToConstant: 24),

            tableView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }

    private func addTableColumns() {
        // Name column
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "Name"
        nameColumn.width = 150
        tableView.addTableColumn(nameColumn)

        // Time column
        let timeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("time"))
        timeColumn.title = "Time"
        timeColumn.width = 80
        tableView.addTableColumn(timeColumn)

        // Notes column
        let notesColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("notes"))
        notesColumn.title = "Notes"
        notesColumn.width = 200
        tableView.addTableColumn(notesColumn)
    }

    private func setupColorFilterButtons() {
        let colors: [TimelineColor] = [.blue, .green, .orange, .purple]

        for (index, color) in colors.enumerated() {
            let button = NSButton(frame: NSRect(x: 0, y: 0, width: 30, height: 30))
            button.wantsLayer = true
            button.layer?.backgroundColor = color.nsColor.cgColor
            button.target = self
            button.action = #selector(colorFilterButtonTapped(_:))
            button.tag = index
            button.toolTip = color.rawValue
            button.isBordered = false
            button.bezelStyle = .regularSquare

            // Add border for selected state
            if selectedColorFilter == color {
                button.layer?.borderWidth = 2
                button.layer?.borderColor = NSColor.white.cgColor
            }

            colorFilterButtons.append(button)
        }
    }

    // MARK: - Editor State Observation

    private func observeEditorState() {
        NotificationCenter.default.addObserver(
            forName: .chapterMarkersDidChange,
            object: editorState,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateDataSource()
            }
        }

        // Initial load
        updateDataSource()
    }

    private func updateDataSource() {
        dataSource.markers = editorState.chapterMarkers
        dataSource.applyFilters()
        tableView.reloadData()
    }

    // MARK: - Actions

    @objc private func searchFieldDidChange(_ sender: NSSearchField) {
        dataSource.searchQuery = sender.stringValue
        dataSource.applyFilters()
        tableView.reloadData()
    }

    @objc private func colorFilterButtonTapped(_ sender: NSButton) {
        let colors: [TimelineColor] = [.blue, .green, .orange, .purple]

        if let color = colors[safe: sender.tag] {
            if selectedColorFilter == color {
                selectedColorFilter = nil
            } else {
                selectedColorFilter = color
            }

            updateColorFilterButtons()
            dataSource.selectedColor = selectedColorFilter
            dataSource.applyFilters()
            tableView.reloadData()
        }
    }

    private func updateColorFilterButtons() {
        let colors: [TimelineColor] = [.blue, .green, .orange, .purple]

        for (index, button) in colorFilterButtons.enumerated() {
            if let color = colors[safe: index] {
                button.layer?.borderWidth = selectedColorFilter == color ? 2 : 0
                button.layer?.borderColor = selectedColorFilter == color ? NSColor.white.cgColor : nil
            }
        }
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        return dataSource.filteredMarkers.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard row < dataSource.filteredMarkers.count else { return nil }

        let marker = dataSource.filteredMarkers[row]

        switch tableColumn?.identifier.rawValue {
        case "name":
            return marker.name
        case "time":
            return formatTime(marker.time)
        case "notes":
            return marker.notes ?? ""
        default:
            return nil
        }
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, shouldEdit tableColumn: NSTableColumn?, row: Int) -> Bool {
        // Allow editing of name and notes columns
        if tableColumn?.identifier.rawValue == "name" || tableColumn?.identifier.rawValue == "notes" {
            return true
        }
        return false
    }

    func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {
        guard row < dataSource.filteredMarkers.count else { return }

        let marker = dataSource.filteredMarkers[row]

        switch tableColumn?.identifier.rawValue {
        case "name":
            if let newName = object as? String {
                updateMarker(marker, newName: newName, notes: marker.notes)
            }
        case "notes":
            if let newNotes = object as? String {
                updateMarker(marker, newName: marker.name, notes: newNotes.isEmpty ? nil : newNotes)
            }
        default:
            break
        }
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = tableView.selectedRow

        if selectedRow >= 0, selectedRow < dataSource.filteredMarkers.count {
            let selectedMarker = dataSource.filteredMarkers[selectedRow]

            // Jump to marker time
            Task {
                do {
                    try await editorState.seek(to: selectedMarker.time)
                } catch {
                    print("Error seeking to marker time: \(error)")
                }
            }
        }
    }

    func tableView(_ tableView: NSTableView, shouldDoubleClickForRowAt row: Int) -> Bool {
        return true
    }

    // MARK: - Private Methods

    private func updateMarker(_ marker: ChapterMarker, newName: String, notes: String?) {
        // Create updated marker
        let updatedMarker = ChapterMarker(
            id: marker.id,
            name: newName,
            time: marker.time,
            notes: notes,
            color: marker.color
        )

        // Update in editor state
        if let index = editorState.chapterMarkers.firstIndex(where: { $0.id == marker.id }) {
            editorState.chapterMarkers[index] = updatedMarker
        }
    }

    private func formatTime(_ time: CMTime) -> String {
        let seconds = CMTimeGetSeconds(time)
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60

        if minutes > 0 {
            return String(format: "%d:%02d", minutes, remainingSeconds)
        } else {
            return String(format: "%d", remainingSeconds)
        }
    }
}

// MARK: - Data Source Helper

@MainActor
private class MarkersDataSource {
    var markers: [ChapterMarker] = []
    var filteredMarkers: [ChapterMarker] = []
    var searchQuery: String = ""
    var selectedColor: TimelineColor?

    func applyFilters() {
        filteredMarkers = markers.filter { marker in
            let matchesSearch = searchQuery.isEmpty || marker.name.localizedCaseInsensitiveContains(searchQuery)
            let matchesColor = selectedColor == nil || marker.color == selectedColor
            return matchesSearch && matchesColor
        }
    }
}

// MARK: - Extension for Color Support

// TimelineColor already has nsColor property in TimelineColor.swift

// MARK: - Array Extension

private extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}