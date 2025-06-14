import XCTest
@testable import nonogramSolver_July2025

final class GameManagerBuilderTests: XCTestCase {
    @MainActor
    func testBuilderLoadsPuzzleWhenEmpty() async {
        let grid = PuzzleGrid(rows: 3, columns: 3)
        let puzzle = GameState(grid: grid, rowCluesBySize: [3: [[1],[2],[3]]], columnCluesBySize: [3: [[1],[2],[3]]])
        let store = InMemoryGameStateStore()
        let loader = MockPuzzleLoader(puzzle: puzzle)
        let builder = GameManagerBuilder(store: store, loader: loader)

        let manager = await builder.build()

        XCTAssertEqual(manager.grid.rows, 3)
        XCTAssertEqual(manager.rowClues, [[1],[2],[3]])
        XCTAssertEqual(manager.columnClues, [[1],[2],[3]])
    }
}
