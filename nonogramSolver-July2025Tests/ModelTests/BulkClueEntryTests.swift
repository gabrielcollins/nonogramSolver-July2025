import XCTest
@testable import nonogramSolver_July2025

final class BulkClueEntryTests: XCTestCase {
    func testParserParsesValidArray() {
        let text = "[[1],[2,3],[4],[5],[6]]"
        let result = BulkClueParser.parse(text)
        XCTAssertEqual(result, [[1],[2,3],[4],[5],[6]])
    }

    func testParserRejectsInvalidArray() {
        let text = "[[1],[-2]]" // negative number and invalid count
        XCTAssertNil(BulkClueParser.parse(text))
    }

    @MainActor
    func testLoadRowAndColumnClues() async {
        let store = InMemoryGameStateStore()
        let manager = GameManager(store: store)
        manager.loadRowClues([[1],[2],[3],[4],[5]])
        manager.loadColumnClues([[1],[1],[1],[1],[1]])
        await manager.save()

        XCTAssertEqual(manager.grid.rows, 5)
        XCTAssertEqual(manager.grid.columns, 5)
        XCTAssertEqual(manager.rowClues[0], [1])
        let saved = await store.load()
        XCTAssertEqual(saved?.rowCluesBySize[5]?.count, 5)
        XCTAssertEqual(saved?.columnCluesBySize[5]?.count, 5)
    }
}
