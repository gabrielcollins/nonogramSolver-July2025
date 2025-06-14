import XCTest
@testable import nonogramSolver_July2025

final class PuzzleServiceTests: XCTestCase {
    func testLoadPuzzleFromBundle() {
        let service = PuzzleService()
        let puzzle = service.loadPuzzle()
        XCTAssertEqual(puzzle?.grid.rows, 5)
        XCTAssertEqual(puzzle?.grid.columns, 5)
    }
}
