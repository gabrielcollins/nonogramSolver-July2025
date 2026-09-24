import XCTest
@testable import nonogramSolver_July2025

/// Covers the "Export JSON" path: the authoring format the creator and the
/// shared contract use (nonogramImageCreator/docs/json-format.md), the
/// metadata it carries through from an import, the solver result it adds, and
/// the contract checks that gate it.
final class ExportTests: XCTestCase {

    /// A 5x5 with every row and column occupied, so it clears the blank-line
    /// gate and is solvable by line logic alone.
    private let solidMatrix: [[Int]] = Array(repeating: Array(repeating: 1, count: 5), count: 5)

    /// A 5x10 (5 columns, 10 rows) with no blank lines, to catch rows and
    /// columns being swapped.
    private let tallMatrix: [[Int]] = (0..<10).map { row in
        (0..<5).map { column in column == row % 5 || column == 0 ? 1 : 0 }
    }

    private func decode(_ json: String) throws -> [String: Any] {
        let data = try XCTUnwrap(json.data(using: .utf8))
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func metadata(_ json: String) throws -> [String: Any] {
        try XCTUnwrap(try decode(json)["metadata"] as? [String: Any])
    }

    // MARK: - Slug and filename

    func testSlugMatchesShippedIDStyle() {
        XCTAssertEqual(GameManager.slug("New Mouse"), "new_mouse")
        XCTAssertEqual(GameManager.slug("6. Mouse!!"), "6_mouse")
        XCTAssertEqual(GameManager.slug("  Duck  "), "duck")
        XCTAssertEqual(GameManager.slug("!!!"), "")
    }

    @MainActor
    func testFilenameFallsBackWhenNameIsUnusable() {
        let manager = GameManager(store: InMemoryGameStateStore())
        manager.puzzleName = "!!!"

        XCTAssertEqual(manager.exportFilename, "puzzle")
    }

    // MARK: - Export gating

    @MainActor
    func testExportBlockedWithoutAName() {
        let manager = GameManager(store: InMemoryGameStateStore())
        manager.importGrid(matrix: solidMatrix)

        XCTAssertFalse(manager.canExport)
        XCTAssertEqual(manager.exportBlocker, "Name the puzzle before exporting")
    }

    @MainActor
    func testExportBlockedByABlankRow() {
        let manager = GameManager(store: InMemoryGameStateStore())
        var matrix = solidMatrix
        matrix[2] = Array(repeating: 0, count: 5)
        manager.importGrid(matrix: matrix)
        manager.puzzleName = "Gappy"

        XCTAssertFalse(manager.canExport)
        XCTAssertEqual(manager.blankLines.rows, [2])
        XCTAssertEqual(manager.exportBlocker, "Blank rows not allowed: 2")
    }

    @MainActor
    func testExportBlockedByABlankColumn() {
        let manager = GameManager(store: InMemoryGameStateStore())
        var matrix = solidMatrix
        for row in matrix.indices { matrix[row][3] = 0 }
        manager.importGrid(matrix: matrix)
        manager.puzzleName = "Gappy"

        XCTAssertFalse(manager.canExport)
        XCTAssertEqual(manager.blankLines.columns, [3])
    }

    @MainActor
    func testExportAllowedOnceNamedAndComplete() {
        let manager = GameManager(store: InMemoryGameStateStore())
        manager.importGrid(matrix: solidMatrix)
        manager.puzzleName = "Mouse"

        XCTAssertTrue(manager.canExport)
        XCTAssertNil(manager.exportBlocker)
    }

    // MARK: - Exported shape

    @MainActor
    func testExportMatchesTheAuthoringSchema() throws {
        let manager = GameManager(store: InMemoryGameStateStore())
        manager.importGrid(matrix: tallMatrix)
        manager.puzzleName = "Tall Mouse"

        let export = try decode(manager.exportJSON)
        XCTAssertEqual(
            Set(export.keys), ["name", "rows", "columns", "matrix", "rowClues", "columnClues", "metadata"]
        )
        XCTAssertEqual(export["name"] as? String, "Tall Mouse")
        XCTAssertEqual(export["rows"] as? Int, 10)
        XCTAssertEqual(export["columns"] as? Int, 5)
        XCTAssertEqual(export["matrix"] as? [[Int]], tallMatrix)
        XCTAssertEqual(export["rowClues"] as? [[Int]], manager.rowClues)
        XCTAssertEqual(export["columnClues"] as? [[Int]], manager.columnClues)
    }

    @MainActor
    func testExportLaysOutKeysInOrderAndOneMatrixRowPerLine() {
        let manager = GameManager(store: InMemoryGameStateStore())
        manager.importGrid(matrix: tallMatrix)
        manager.puzzleName = "Tall Mouse"

        let lines = manager.exportJSON.components(separatedBy: "\n")
        let keys = ["name", "rows", "columns", "matrix", "rowClues", "columnClues", "metadata"]
        let keyLines = keys.map { key in lines.firstIndex { $0.hasPrefix("  \"\(key)\":") } }
        XCTAssertFalse(keyLines.contains(nil), "every key starts its own line")
        XCTAssertEqual(keyLines.compactMap { $0 }, keyLines.compactMap { $0 }.sorted(), "keys in contract order")
        XCTAssertTrue(lines.contains("    [1,1,0,0,0],"), "each matrix row sits on one line, without spaces")
        XCTAssertTrue(lines.contains { $0.hasPrefix("  \"rowClues\": [[") }, "clues sit on one line")
    }

    @MainActor
    func testExportTrimsWhitespaceFromTheName() throws {
        let manager = GameManager(store: InMemoryGameStateStore())
        manager.importGrid(matrix: solidMatrix)
        manager.puzzleName = "  Mouse  "

        XCTAssertEqual(try decode(manager.exportJSON)["name"] as? String, "Mouse")
    }

    // MARK: - Metadata

    @MainActor
    func testExportKeepsTheImportedMetadata() throws {
        let manager = GameManager(store: InMemoryGameStateStore())
        manager.importGrid(matrix: solidMatrix, metadata: [
            "createdBy": .string("Original puzzle design"),
            "sourceNumber": .integer(2),
            "style": .string("animal-silhouette"),
        ])
        manager.puzzleName = "Marmot"

        let metadata = try metadata(manager.exportJSON)
        XCTAssertEqual(metadata["createdBy"] as? String, "Original puzzle design")
        XCTAssertEqual(metadata["sourceNumber"] as? Int, 2)
        XCTAssertEqual(metadata["style"] as? String, "animal-silhouette")
    }

    @MainActor
    func testUnsolvedExportIsUnverifiedAndKeepsTheImportedDifficulty() throws {
        let manager = GameManager(store: InMemoryGameStateStore())
        manager.importGrid(matrix: solidMatrix, metadata: ["difficulty": .string("difficult")])
        manager.puzzleName = "Marmot"

        let metadata = try metadata(manager.exportJSON)
        XCTAssertEqual(metadata["difficulty"] as? String, "difficult")
        XCTAssertEqual(metadata["solverCheck"] as? String, "unverified")
        XCTAssertNil(metadata["lineSteps"], "no solve, nothing to count")
    }

    @MainActor
    func testSolvedExportRecordsTheLineSolverResult() async throws {
        let manager = GameManager(store: InMemoryGameStateStore())
        manager.importGrid(matrix: solidMatrix, metadata: ["difficulty": .string("difficult")])
        manager.puzzleName = "Marmot"
        manager.clearBoard()

        await manager.autoSolve()

        let metadata = try metadata(manager.exportJSON)
        XCTAssertEqual(metadata["solverCheck"] as? String, "UNIQUE")
        XCTAssertEqual(metadata["lineSteps"] as? Int, manager.solvingStepCount)
        XCTAssertEqual(metadata["difficulty"] as? String, manager.derivedDifficulty, "a measured solve wins")
    }

    @MainActor
    func testExportWithoutImportedMetadataCreditsTheSolver() throws {
        let manager = GameManager(store: InMemoryGameStateStore())
        manager.importGrid(matrix: solidMatrix)
        manager.puzzleName = "Mouse"

        let metadata = try metadata(manager.exportJSON)
        XCTAssertEqual(metadata["createdBy"] as? String, "nonogramSolver")
        XCTAssertEqual(metadata["difficulty"] as? String, GameManager.mediumDifficulty)
    }

    @MainActor
    func testANewImportOrGridSizeDropsThePreviousMetadata() {
        let manager = GameManager(store: InMemoryGameStateStore())
        manager.importGrid(matrix: solidMatrix, metadata: ["style": .string("animal-silhouette")])
        manager.importGrid(matrix: solidMatrix)
        XCTAssertEqual(manager.importedMetadata, [:], "an import without metadata replaces it")

        manager.importGrid(matrix: solidMatrix, metadata: ["style": .string("animal-silhouette")])
        manager.set(rows: 10, columns: 10)
        XCTAssertEqual(manager.importedMetadata, [:], "a new grid size is a new puzzle")
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
    func testExportReimportsWithItsNameMatrixAndMetadata() throws {
        let manager = GameManager(store: InMemoryGameStateStore())
        manager.importGrid(matrix: tallMatrix, metadata: ["sourceTitle": .string("Sitting Watch")])
        manager.puzzleName = "Tall Mouse"

        let parsed = try XCTUnwrap(try? PuzzleImportParser.parsePuzzles(manager.exportJSON).get())

        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[0].name, "Tall Mouse")
        XCTAssertEqual(parsed[0].matrix, tallMatrix)
        XCTAssertEqual(parsed[0].metadata?["sourceTitle"], .string("Sitting Watch"))
    }
}
