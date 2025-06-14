import XCTest
@testable import nonogramSolver_July2025

final class PuzzleGridTests: XCTestCase {
    func testInitializationCreatesUnmarkedTiles() throws {
        let grid = PuzzleGrid(rows: 3, columns: 2)
        XCTAssertEqual(grid.rows, 3)
        XCTAssertEqual(grid.columns, 2)
        XCTAssertEqual(grid.tiles.count, 3)
        XCTAssertEqual(grid.tiles[0].count, 2)
        XCTAssertTrue(grid.tiles.flatMap { $0 }.allSatisfy { $0 == .unmarked })
    }
}
