import XCTest
@testable import nonogramSolver_July2025

final class GameManagerTests: XCTestCase {

    @MainActor
    func testUpdateRowAndColumnClues() async {
        let store = InMemoryGameStateStore()
        let manager = GameManager(store: store)

        manager.updateRowClue(row: 0, string: "1 2 3")
        manager.updateColumnClue(column: 0, string: "4 5")

        XCTAssertEqual(manager.rowClues[0], [1,2,3])
        XCTAssertEqual(manager.columnClues[0], [4,5])
    }

    @MainActor
    func testSetGridPersistsClues() async {
        let store = InMemoryGameStateStore()
        let manager = GameManager(store: store)

        // update clue for default size (20x15)
        manager.updateRowClue(row: 0, string: "1")
        // change size and update clue for new grid
        manager.set(rows: 2, columns: 2)
        manager.updateRowClue(row: 0, string: "2")

        // switch back to original size
        manager.set(rows: 20, columns: 15)
        await manager.save()

        let loaded = await store.load()
        XCTAssertEqual(loaded?.rowCluesBySize[20]?[0], [1])
        XCTAssertEqual(loaded?.rowCluesBySize[2]?[0], [2])
    }

    @MainActor
    func testClearBoardResetsState() async {
        let manager = GameManager()
        manager.tap(row: 0, column: 0)
        manager.stepSolve()

        manager.clearBoard()

        XCTAssertTrue(manager.grid.tiles.flatMap { $0 }.allSatisfy { $0 == .unmarked })
        XCTAssertEqual(manager.highlightedRow, manager.grid.rows - 1)
        XCTAssertNil(manager.highlightedColumn)
    }
}
