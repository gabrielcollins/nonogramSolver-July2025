import XCTest
@testable import nonogramSolver_July2025

final class LineSolverTests: XCTestCase {

    // MARK: - Single clue

    func testSingleClueMarksOverlapCellsFilled() {
        // [3] in length 5: starts 0-2 overlap only at the middle cell.
        let result = LineSolver.solve(
            line: Array(repeating: .unmarked, count: 5),
            clues: [3]
        )

        XCTAssertEqual(result, .deduced([.unmarked, .unmarked, .filled, .unmarked, .unmarked]))
    }

    func testFullLineClueFillsEveryCell() {
        let result = LineSolver.solve(
            line: Array(repeating: .unmarked, count: 5),
            clues: [5]
        )

        XCTAssertEqual(result, .deduced(Array(repeating: .filled, count: 5)))
    }

    // MARK: - Multiple clues

    func testTightMultiClueLineIsFullyDeduced() {
        // [1, 1] in length 3 has exactly one arrangement.
        let result = LineSolver.solve(
            line: Array(repeating: .unmarked, count: 3),
            clues: [1, 1]
        )

        XCTAssertEqual(result, .deduced([.filled, .empty, .filled]))
    }

    // MARK: - Existing constraints

    func testExistingEmptyCellConstrainsPlacement() {
        // [3] in length 5 with cell 0 empty: starts 1-2 remain, cells 2-3 overlap.
        let result = LineSolver.solve(
            line: [.empty, .unmarked, .unmarked, .unmarked, .unmarked],
            clues: [3]
        )

        XCTAssertEqual(result, .deduced([.empty, .unmarked, .filled, .filled, .unmarked]))
    }

    func testExistingFilledCellsArePreserved() {
        // [1] in length 3 with the middle cell already filled: fully determined.
        let result = LineSolver.solve(
            line: [.unmarked, .filled, .unmarked],
            clues: [1]
        )

        XCTAssertEqual(result, .deduced([.empty, .filled, .empty]))
    }

    // MARK: - Contradictions

    func testClueLongerThanLineIsAContradiction() {
        let result = LineSolver.solve(
            line: Array(repeating: .unmarked, count: 5),
            clues: [6]
        )

        XCTAssertEqual(result, .contradiction)
    }

    func testCluesConflictingWithLineStateAreAContradiction() {
        // [1] cannot be satisfied when two separated cells are already filled.
        let result = LineSolver.solve(
            line: [.filled, .unmarked, .filled],
            clues: [1]
        )

        XCTAssertEqual(result, .contradiction)
    }

    func testEmptyCluesWithFilledCellAreAContradiction() {
        let result = LineSolver.solve(
            line: [.unmarked, .filled, .unmarked],
            clues: []
        )

        XCTAssertEqual(result, .contradiction)
    }

    func testEmptyCluesClearAnUnmarkedLine() {
        let result = LineSolver.solve(
            line: Array(repeating: .unmarked, count: 3),
            clues: []
        )

        XCTAssertEqual(result, .deduced(Array(repeating: .empty, count: 3)))
    }
}
