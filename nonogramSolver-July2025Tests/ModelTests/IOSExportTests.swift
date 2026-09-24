import XCTest
@testable import nonogramSolver_July2025

/// Covers the single "Export for iOS App" path: the PuzzleSet the game reads,
/// the id/name/difficulty it carries, and the contract checks that gate it.
final class IOSExportTests: XCTestCase {

    /// A 5x5 with every row and column occupied, so it clears the blank-line
    /// gate and is solvable by line logic alone.
    private let solidMatrix: [[Int]] = Array(repeating: Array(repeating: 1, count: 5), count: 5)

    private func decode(_ json: String) throws -> [String: Any] {
        let data = try XCTUnwrap(json.data(using: .utf8))
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: - Slug and id

    func testSlugMatchesShippedIDStyle() {
        XCTAssertEqual(GameManager.slug("New Mouse"), "new_mouse")
        XCTAssertEqual(GameManager.slug("6. Mouse!!"), "6_mouse")
        XCTAssertEqual(GameManager.slug("  Duck  "), "duck")
        XCTAssertEqual(GameManager.slug("!!!"), "")
    }

    @MainActor
    func testIDCombinesSetAndName() {
        let manager = GameManager(store: InMemoryGameStateStore())
        manager.puzzleName = "New Mouse"

        XCTAssertEqual(manager.iosPuzzleID, "testing_new_mouse")
    }

    @MainActor
    func testFilenameFallsBackWhenNameIsUnusable() {
        let manager = GameManager(store: InMemoryGameStateStore())
        manager.puzzleName = "!!!"

        XCTAssertEqual(manager.iosExportFilename, "puzzle")
    }

    // MARK: - Export gating

    @MainActor
    func testExportBlockedWithoutAName() {
        let manager = GameManager(store: InMemoryGameStateStore())
        manager.importGrid(matrix: solidMatrix)

        XCTAssertFalse(manager.canExportForIOS)
        XCTAssertEqual(manager.iosExportBlocker, "Name the puzzle before exporting")
    }

    @MainActor
    func testExportBlockedByABlankRow() {
        let manager = GameManager(store: InMemoryGameStateStore())
        var matrix = solidMatrix
        matrix[2] = Array(repeating: 0, count: 5)
        manager.importGrid(matrix: matrix)
        manager.puzzleName = "Gappy"

        XCTAssertFalse(manager.canExportForIOS)
        XCTAssertEqual(manager.blankLines.rows, [2])
        XCTAssertEqual(manager.iosExportBlocker, "Blank rows not allowed: 2")
    }

    @MainActor
    func testExportBlockedByABlankColumn() {
        let manager = GameManager(store: InMemoryGameStateStore())
        var matrix = solidMatrix
        for row in matrix.indices { matrix[row][3] = 0 }
        manager.importGrid(matrix: matrix)
        manager.puzzleName = "Gappy"

        XCTAssertFalse(manager.canExportForIOS)
        XCTAssertEqual(manager.blankLines.columns, [3])
    }

    @MainActor
    func testExportAllowedOnceNamedAndComplete() {
        let manager = GameManager(store: InMemoryGameStateStore())
        manager.importGrid(matrix: solidMatrix)
        manager.puzzleName = "Mouse"

        XCTAssertTrue(manager.canExportForIOS)
        XCTAssertNil(manager.iosExportBlocker)
    }

    // MARK: - Exported shape

    @MainActor
    func testExportMatchesThePuzzleSetSchema() throws {
        let manager = GameManager(store: InMemoryGameStateStore())
        manager.importGrid(matrix: solidMatrix)
        manager.puzzleName = "New Mouse"

        let set = try decode(manager.iosExportJSON)
        XCTAssertEqual(set["setName"] as? String, "Testing")
        let puzzles = try XCTUnwrap(set["puzzles"] as? [[String: Any]])
        XCTAssertEqual(puzzles.count, 1)

        let puzzle = puzzles[0]
        XCTAssertEqual(puzzle["id"] as? String, "testing_new_mouse")
        XCTAssertEqual(puzzle["name"] as? String, "New Mouse")
        XCTAssertNotNil(puzzle["difficulty"] as? String)
        XCTAssertEqual(puzzle["solution"] as? [[Int]], solidMatrix)
    }

    @MainActor
    func testExportOmitsCluesBecauseTheGameDerivesThem() throws {
        let manager = GameManager(store: InMemoryGameStateStore())
        manager.importGrid(matrix: solidMatrix)
        manager.puzzleName = "Mouse"

        let puzzle = try XCTUnwrap((try decode(manager.iosExportJSON)["puzzles"] as? [[String: Any]])?.first)
        XCTAssertNil(puzzle["rowClues"])
        XCTAssertNil(puzzle["columnClues"])
        XCTAssertEqual(Set(puzzle.keys), ["id", "name", "difficulty", "solution"])
    }

    @MainActor
    func testExportTrimsWhitespaceFromTheName() throws {
        let manager = GameManager(store: InMemoryGameStateStore())
        manager.importGrid(matrix: solidMatrix)
        manager.puzzleName = "  Mouse  "

        let puzzle = try XCTUnwrap((try decode(manager.iosExportJSON)["puzzles"] as? [[String: Any]])?.first)
        XCTAssertEqual(puzzle["name"] as? String, "Mouse")
    }

    // MARK: - Difficulty

    @MainActor
    func testSweepsNormaliseStepCountByGridSize() {
        let manager = GameManager(store: InMemoryGameStateStore())
        manager.importGrid(matrix: solidMatrix)  // 5x5 -> 10 lines per sweep

        manager.solvingStepCount = 20

        XCTAssertEqual(manager.solverSweeps, 2.0, accuracy: 0.001)
    }

    @MainActor
    func testUnsolvedBoardReportsAnUnmeasuredFallback() {
        let manager = GameManager(store: InMemoryGameStateStore())
        manager.importGrid(matrix: solidMatrix)

        // Import leaves empty cells unmarked, so nothing is verified yet.
        XCTAssertFalse(manager.difficultyIsMeasured)
        XCTAssertEqual(manager.derivedDifficulty, "medium")
    }

    @MainActor
    func testSolvedBoardReportsAMeasuredDifficultyConsistentWithItsSweeps() async {
        let manager = GameManager(store: InMemoryGameStateStore())
        manager.importGrid(matrix: solidMatrix)
        manager.clearBoard()

        await manager.autoSolve()

        XCTAssertTrue(manager.isPuzzleSolved)
        XCTAssertTrue(manager.difficultyIsMeasured)

        // Assert the mapping rather than a hard-coded step count, so the test
        // survives solver changes that shift the count.
        let expected: String
        switch manager.solverSweeps {
        case ..<2.0: expected = GameManager.easyDifficulty
        case ..<3.5: expected = GameManager.mediumDifficulty
        default: expected = GameManager.difficultDifficulty
        }
        XCTAssertEqual(manager.derivedDifficulty, expected)
    }

    @MainActor
    func testDifficultyVocabularyMatchesTheShippedData() {
        // The game's own testing.json uses "medium" and "difficult"; emitting
        // "hard" would add a third spelling for the same idea.
        XCTAssertEqual(GameManager.difficultDifficulty, "difficult")
        XCTAssertEqual(GameManager.mediumDifficulty, "medium")
    }

    // MARK: - Round trip

    @MainActor
    func testExportedSetReimportsUnchanged() throws {
        let manager = GameManager(store: InMemoryGameStateStore())
        manager.importGrid(matrix: solidMatrix)
        manager.puzzleName = "New Mouse"

        let data = try XCTUnwrap(manager.iosExportJSON.data(using: .utf8))
        let parsed = try XCTUnwrap(try? PuzzleImportParser.parsePuzzles(data).get())

        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[0].name, "New Mouse")
        XCTAssertEqual(parsed[0].matrix, solidMatrix)
    }
}
