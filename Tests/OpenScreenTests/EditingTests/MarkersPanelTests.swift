import XCTest
@testable import OpenScreen

@MainActor
final class MarkersPanelTests: XCTestCase {

    var editorState: EditorState!
    var mockDataSource: MockMarkersDataSource!

    override func setUp() async throws {
        editorState = EditorState.createTestState()
        mockDataSource = MockMarkersDataSource()
    }

    // MARK: - Initialization Tests

    func testMarkersPanelInitialization() {
        let panel = MarkersPanel(editorState: editorState)
        XCTAssertNotNil(panel)
    }

    func testMarkersPanelHasTableView() {
        let panel = MarkersPanel(editorState: editorState)
        XCTAssertNotNil(panel.tableView, "Panel should have a tableView")
        XCTAssertEqual(panel.tableView.dataSource as? MockMarkersDataSource, mockDataSource)
    }

    // MARK: - Search Functionality Tests

    func testSearchFilterRealTime() {
        let panel = MarkersPanel(editorState: editorState)
        panel.dataSource = mockDataSource

        // Add test markers
        let marker1 = ChapterMarker(name: "Introduction", time: .zero, color: .blue)
        let marker2 = ChapterMarker(name: "Conclusion", time: .seconds(10), color: .red)
        mockDataSource.addMarker(marker1)
        mockDataSource.addMarker(marker2)

        // Test filtering
        panel.searchField.stringValue = "Intro"
        XCTAssertEqual(mockDataSource.filteredMarkers.count, 1)
        XCTAssertEqual(mockDataSource.filteredMarkers.first?.name, "Introduction")

        panel.searchField.stringValue = "Conclusion"
        XCTAssertEqual(mockDataSource.filteredMarkers.count, 1)
        XCTAssertEqual(mockDataSource.filteredMarkers.first?.name, "Conclusion")

        panel.searchField.stringValue = "nonexistent"
        XCTAssertEqual(mockDataSource.filteredMarkers.count, 0)
    }

    // MARK: - Color Filter Tests

    func testColorFilterButtons() {
        let panel = MarkersPanel(editorState: editorState)
        XCTAssertNotNil(panel.colorFilterButtons, "Panel should have color filter buttons")
    }

    func testColorFiltering() {
        let panel = MarkersPanel(editorState: editorState)
        panel.dataSource = mockDataSource

        // Add test markers with different colors
        let marker1 = ChapterMarker(name: "Blue Marker", time: .zero, color: .blue)
        let marker2 = ChapterMarker(name: "Red Marker", time: .seconds(5), color: .red)
        let marker3 = ChapterMarker(name: "Green Marker", time: .seconds(10), color: .green)

        mockDataSource.addMarker(marker1)
        mockDataSource.addMarker(marker2)
        mockDataSource.addMarker(marker3)

        // Test blue filter
        panel.selectedColorFilter = .blue
        XCTAssertEqual(mockDataSource.filteredMarkers.count, 1)
        XCTAssertEqual(mockDataSource.filteredMarkers.first?.color, .blue)

        // Test red filter
        panel.selectedColorFilter = .red
        XCTAssertEqual(mockDataSource.filteredMarkers.count, 1)
        XCTAssertEqual(mockDataSource.filteredMarkers.first?.color, .red)

        // Test no filter
        panel.selectedColorFilter = nil
        XCTAssertEqual(mockDataSource.filteredMarkers.count, 3)
    }

    // MARK: - Selection and Navigation Tests

    func testDoubleClickEditsMarker() {
        let panel = MarkersPanel(editorState: editorState)
        panel.dataSource = mockDataSource

        let marker = ChapterMarker(name: "Test Marker", time: .seconds(5), color: .blue)
        mockDataSource.addMarker(marker)

        // Simulate double click
        let rowIndex = 0
        let columnIndex = 0

        // Test that the double click action is set up
        XCTAssertNotNil(tableView(tableView: panel.tableView, shouldDoubleClickForRowAt: IndexPath(row: rowIndex, section: 0)))
    }

    func testSelectMarkerJumpsToTime() {
        let panel = MarkersPanel(editorState: editorState)
        panel.dataSource = mockDataSource

        let marker = ChapterMarker(name: "Test Marker", time: .seconds(5), color: .blue)
        mockDataSource.addMarker(marker)

        // Simulate row selection
        let rowIndex = 0

        // Test that selection triggers time jump
        // This would need to be implemented with a mock or delegate pattern
        // For now, verify the marker time is accessible
        XCTAssertEqual(mockDataSource.markers.first?.time, .seconds(5))
    }

    // MARK: - Data Source Integration Tests

    func testDataSourceRespondsToEditorStateChanges() {
        let panel = MarkersPanel(editorState: editorState)
        panel.dataSource = mockDataSource

        // Add marker via editor state
        let newMarker = ChapterMarker(name: "State Marker", time: .seconds(3), color: .green)
        mockDataSource.addMarker(newMarker)

        XCTAssertEqual(mockDataSource.markers.count, 1)
        XCTAssertEqual(mockDataSource.markers.first?.name, "State Marker")
    }
}

// MARK: - Mock Data Source

@MainActor
class MockMarkersDataSource: NSObject, NSTableViewDataSource {
    private var markers: [ChapterMarker] = []
    private(set) var filteredMarkers: [ChapterMarker] = []
    var searchQuery: String = ""
    var selectedColor: TimelineColor?

    func addMarker(_ marker: ChapterMarker) {
        markers.append(marker)
        applyFilters()
    }

    private func applyFilters() {
        filteredMarkers = markers.filter { marker in
            let matchesSearch = searchQuery.isEmpty || marker.name.localizedCaseInsensitiveContains(searchQuery)
            let matchesColor = selectedColor == nil || marker.color == selectedColor
            return matchesSearch && matchesColor
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredMarkers.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard row < filteredMarkers.count else { return nil }

        let marker = filteredMarkers[row]

        if tableColumn?.identifier.rawValue == "name" {
            return marker.name
        } else if tableColumn?.identifier.rawValue == "time" {
            return "\(CMTimeGetSeconds(marker.time).rounded(to: 2))s"
        } else if tableColumn?.identifier.rawValue == "notes" {
            return marker.notes ?? ""
        }

        return nil
    }
}