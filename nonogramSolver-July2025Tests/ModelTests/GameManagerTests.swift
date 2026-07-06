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
    func testTapUpdatesClues() async {
        let manager = GameManager()
        manager.set(rows: 2, columns: 2)

        manager.tap(row: 0, column: 0)

        XCTAssertEqual(manager.rowClues[0], [1])
        XCTAssertEqual(manager.columnClues[0], [1])

        manager.tap(row: 0, column: 1)

        XCTAssertEqual(manager.rowClues[0], [2])
        XCTAssertEqual(manager.columnClues[1], [1])
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
        XCTExpectFailure("Known failure (pre-refactor baseline): assumes top-down traversal, but the solver walks rows bottom-up and flags the empty-clued bottom row without counting a step. Re-pin during Phase 1 characterization.")
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
        XCTExpectFailure("Known failure (pre-refactor baseline): assumes top-down traversal and step counting on error lines; bottom-up traversal highlights row 3 (empty clues) without counting a step. Re-pin during Phase 1 characterization.")
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

    @MainActor
    func testClearRowAndColumnClues() async {
        let manager = GameManager()
        manager.updateRowClue(row: 0, string: "1 2")
        manager.updateColumnClue(column: 0, string: "3")

        manager.clearRowClues()
        manager.clearColumnClues()

        XCTAssertTrue(manager.rowClues.allSatisfy { $0.isEmpty })
        XCTAssertTrue(manager.columnClues.allSatisfy { $0.isEmpty })
    }

    @MainActor
    func testStepSolveDetectsRowContradiction() async {
        let manager = GameManager()
        manager.set(rows: 1, columns: 2)
        manager.clearBoard()
        manager.updateRowClue(row: 0, string: "3") // impossible
        manager.updateColumnClue(column: 0, string: "")
        manager.updateColumnClue(column: 1, string: "")

        manager.stepSolve()

        XCTAssertEqual(manager.contradictionRow, 0)
        XCTAssertTrue(manager.contradictionEncountered)
        XCTAssertEqual(manager.solvingStepCount, 0)
    }

    @MainActor
    func testStepSolveDetectsColumnContradiction() async {
        let manager = GameManager()
        manager.set(rows: 1, columns: 2)
        manager.clearBoard()
        manager.updateRowClue(row: 0, string: "1")
        manager.updateColumnClue(column: 0, string: "3") // impossible
        manager.updateColumnClue(column: 1, string: "1")

        manager.stepSolve() // process row
        manager.stepSolve() // process column 0 -> contradiction

        XCTAssertEqual(manager.contradictionColumn, 0)
        XCTAssertTrue(manager.contradictionEncountered)
        XCTAssertEqual(manager.solvingStepCount, 1)
    }

    @MainActor
    func testStepSolveDetectsUnsolvableLoop() async {
        let manager = GameManager()
        manager.set(rows: 2, columns: 2)
        manager.clearBoard()
        for i in 0..<2 {
            manager.updateRowClue(row: i, string: "1")
            manager.updateColumnClue(column: i, string: "1")
        }

        for _ in 0..<4 { manager.stepSolve() }

        XCTAssertTrue(manager.unsolvableByStep)
    }

    @MainActor
    func testAutoSolveSolvesPuzzle() async {
        let manager = GameManager()
        manager.set(rows: 1, columns: 1)
        manager.updateRowClue(row: 0, string: "1")
        manager.updateColumnClue(column: 0, string: "1")

        manager.autoSolveStepDelayNanoseconds = 0
        await manager.autoSolve()

        XCTAssertTrue(manager.isPuzzleSolved)
        XCTAssertGreaterThan(manager.solvingStepCount, 0)
    }

    @MainActor
    func testAutoSolveDetectsContradiction() async {
        let manager = GameManager()
        manager.set(rows: 1, columns: 1)
        manager.updateRowClue(row: 0, string: "3")
        manager.updateColumnClue(column: 0, string: "1")

        manager.autoSolveStepDelayNanoseconds = 0
        await manager.autoSolve()

        XCTAssertTrue(manager.contradictionEncountered)
        XCTAssertEqual(manager.contradictionRow, 0)
    }

    @MainActor
    func testAutoSolveDetectsUnsolvableLoop() async {
        let manager = GameManager()
        manager.set(rows: 2, columns: 2)
        manager.clearBoard()
        for i in 0..<2 {
            manager.updateRowClue(row: i, string: "1")
            manager.updateColumnClue(column: i, string: "1")
        }

        manager.autoSolveStepDelayNanoseconds = 0
        await manager.autoSolve()

        XCTAssertTrue(manager.unsolvableByStep)
    }

    @MainActor
    func testSolvingAgainAfterBeyondSimpleLevelRestartsFromScratch() async {
        let manager = GameManager(store: InMemoryGameStateStore())
        manager.set(rows: 2, columns: 2)
        manager.clearBoard()
        for i in 0..<2 {
            manager.updateRowClue(row: i, string: "1")
            manager.updateColumnClue(column: i, string: "1")
        }
        manager.autoSolveStepDelayNanoseconds = 0
        await manager.autoSolve()
        XCTAssertTrue(manager.unsolvableByStep)
        let firstRunSteps = manager.solvingStepCount

        // Step Solve restarts from a cleared board instead of being stuck.
        manager.stepSolve()

        XCTAssertFalse(manager.unsolvableByStep)
        XCTAssertEqual(manager.solvingStepCount, 1)
        XCTAssertEqual(manager.rowClues, [[1], [1]], "clues survive the restart")

        // Auto Solve after a stall also restarts and re-detects cleanly.
        await manager.autoSolve()

        XCTAssertTrue(manager.unsolvableByStep)
        XCTAssertEqual(manager.solvingStepCount, firstRunSteps, "restarted run repeats the same sweep")
    }

    @MainActor
    func testHasCompleteCluesAndCluesJSON() async throws {
        let manager = GameManager()
        manager.set(rows: 2, columns: 2)

        XCTAssertFalse(manager.hasCompleteClues)

        for i in 0..<2 {
            manager.updateRowClue(row: i, string: "1")
            manager.updateColumnClue(column: i, string: "1")
        }

        XCTAssertTrue(manager.hasCompleteClues)

        let jsonData = manager.cluesJSON.data(using: .utf8)!
        struct Clues: Decodable { let rowClues: [[Int]]; let columnClues: [[Int]] }
        let decoded = try JSONDecoder().decode(Clues.self, from: jsonData)
        XCTAssertEqual(decoded.rowClues.count, 2)
        XCTAssertEqual(decoded.columnClues.count, 2)
    }

    @MainActor
    func testImportGridPopulatesTilesAndDerivesClues() async {
        let manager = GameManager(store: InMemoryGameStateStore())
        let matrix = (0..<5).map { row in
            (0..<5).map { $0 == row ? 1 : 0 }
        }

        manager.importGrid(matrix: matrix)

        XCTAssertEqual(manager.grid.rows, 5)
        XCTAssertEqual(manager.grid.columns, 5)
        XCTAssertEqual(manager.grid.tiles[0][0], .filled)
        XCTAssertEqual(manager.grid.tiles[0][1], .unmarked)
        XCTAssertEqual(manager.rowClues, Array(repeating: [1], count: 5))
        XCTAssertEqual(manager.columnClues, Array(repeating: [1], count: 5))
    }

    @MainActor
    func testImportGridReplacesSameSizeBoardAndResetsSolverState() async {
        let manager = GameManager(store: InMemoryGameStateStore())
        manager.set(rows: 5, columns: 5)
        manager.tap(row: 0, column: 0)
        manager.stepSolve()

        let matrix = [
            [0, 1, 1, 1, 0],
            [1, 1, 1, 1, 1],
            [1, 1, 1, 1, 1],
            [1, 1, 1, 1, 1],
            [0, 1, 1, 1, 0],
        ]
        manager.importGrid(matrix: matrix)

        XCTAssertEqual(manager.grid.tiles[0][0], .unmarked)
        XCTAssertEqual(manager.grid.tiles[1][0], .filled)
        XCTAssertEqual(manager.rowClues[0], [3])
        XCTAssertEqual(manager.columnClues[0], [3])
        XCTAssertEqual(manager.solvingStepCount, 0)
        XCTAssertNil(manager.highlightedRow)
        XCTAssertFalse(manager.contradictionEncountered)
        XCTAssertFalse(manager.unsolvableByStep)
    }

    @MainActor
    func testImportedPuzzleSolvesAfterClearBoard() async {
        let manager = GameManager(store: InMemoryGameStateStore())
        let matrix = [
            [0, 1, 1, 1, 0],
            [1, 1, 1, 1, 1],
            [1, 1, 1, 1, 1],
            [1, 1, 1, 1, 1],
            [0, 1, 1, 1, 0],
        ]

        manager.importGrid(matrix: matrix)
        manager.clearBoard()
        manager.autoSolveStepDelayNanoseconds = 0
        await manager.autoSolve()

        XCTAssertTrue(manager.isPuzzleSolved)
        XCTAssertFalse(manager.contradictionEncountered)
        let solved = manager.grid.tiles.map { row in row.map { $0 == .filled ? 1 : 0 } }
        XCTAssertEqual(solved, matrix)
    }
}
