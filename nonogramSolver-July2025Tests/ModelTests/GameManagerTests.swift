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
        XCTAssertEqual(manager.solvingStepCount, 1)

        manager.clearBoard()

        XCTAssertTrue(manager.grid.tiles.flatMap { $0 }.allSatisfy { $0 == .unmarked })
        XCTAssertEqual(manager.highlightedRow, manager.grid.rows - 1)
        XCTAssertNil(manager.highlightedColumn)
        XCTAssertEqual(manager.solvingStepCount, 0)
    }

    @MainActor
    func testStepSolveSkipsSolvedRows() async {
        let manager = GameManager()
        manager.set(rows: 3, columns: 1)
        for row in 0..<3 { manager.updateRowClue(row: row, string: "") }
        manager.updateColumnClue(column: 0, string: "")

        // mark middle row solved
        manager.tap(row: 1, column: 0)

        manager.stepSolve()

        XCTAssertEqual(manager.highlightedRow, 0)
        XCTAssertEqual(manager.solvingStepCount, 1)
    }

    @MainActor
    func testIsPuzzleSolved() async {
        let manager = GameManager()
        manager.set(rows: 2, columns: 2)
        for r in 0..<2 { for c in 0..<2 { manager.tap(row: r, column: c) } }
        XCTAssertTrue(manager.isPuzzleSolved)
        manager.clearBoard()
        XCTAssertFalse(manager.isPuzzleSolved)
    }

    @MainActor
    func testStepSolveHighlightsMissingRowClue() async {
        let manager = GameManager()
        manager.set(rows: 2, columns: 1)

        manager.stepSolve()

        XCTAssertEqual(manager.errorRow, 1)
        XCTAssertEqual(manager.solvingStepCount, 0)

        manager.stepSolve()

        XCTAssertNil(manager.errorRow)
        XCTAssertEqual(manager.highlightedRow, 0)
        XCTAssertEqual(manager.solvingStepCount, 0)
    }

    @MainActor
    func testStepSolveHighlightsMissingColumnClue() async {
        let manager = GameManager()
        manager.set(rows: 1, columns: 2)
        manager.updateRowClue(row: 0, string: "1")

        manager.stepSolve() // solve row

        manager.stepSolve() // should flag first column

        XCTAssertEqual(manager.errorColumn, 0)
        XCTAssertEqual(manager.solvingStepCount, 1)

        manager.stepSolve() // clear flag and move to next column

        XCTAssertNil(manager.errorColumn)
        XCTAssertEqual(manager.highlightedColumn, 1)
        XCTAssertEqual(manager.solvingStepCount, 1)
    }
}
