import XCTest
@testable import nonogramSolver_July2025

final class BulkClueEntryTests: XCTestCase {
    func testParserParsesValidArray() {
        let text = "[[1],[2,3],[4],[5],[6]]"
        let result = BulkClueParser.parse(text)
        switch result {
        case .success(let clues):
            XCTAssertEqual(clues, [[1],[2,3],[4],[5],[6]])
        default:
            XCTFail("Expected success")
        }
    }

    func testParserIgnoresWhitespace() {
        let text = "\n  [[1], [2],\n   [3], [4],\n   [5]]  "
        let result = BulkClueParser.parse(text)
        switch result {
        case .success(let clues):
            XCTAssertEqual(clues, [[1],[2],[3],[4],[5]])
        default:
            XCTFail("Expected success")
        }
    }

    func testParserRejectsInvalidArray() {
        let text = "[[1],[-2]]" // negative number and invalid count
        let result = BulkClueParser.parse(text)
        switch result {
        case .failure(let error):
            XCTAssertEqual(error, .nonPositiveNumbers)
        default:
            XCTFail("Expected failure")
        }
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
