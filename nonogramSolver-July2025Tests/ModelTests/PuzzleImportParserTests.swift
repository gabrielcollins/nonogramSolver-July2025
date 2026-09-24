import XCTest
@testable import nonogramSolver_July2025

final class PuzzleImportParserTests: XCTestCase {

    private let validMatrix: [[Int]] = (0..<5).map { row in
        (0..<5).map { $0 == row ? 1 : 0 }
    }

    func testParsesBareMatrix() throws {
        let data = try JSONEncoder().encode(validMatrix)

        XCTAssertEqual(PuzzleImportParser.parse(data), .success(validMatrix))
    }

    func testParsesCreatorExportObject() throws {
        let export: [String: Any] = [
            "name": "marmot_5x5",
            "rows": 5,
            "columns": 5,
            "matrix": validMatrix,
            "rowClues": [[1], [1], [1], [1], [1]],
            "columnClues": [[1], [1], [1], [1], [1]],
            "metadata": ["createdBy": "nonogramImageCreator"],
        ]
        let data = try JSONSerialization.data(withJSONObject: export)

        XCTAssertEqual(PuzzleImportParser.parse(data), .success(validMatrix))
    }

    func testRejectsNonJSONInput() {
        XCTAssertEqual(PuzzleImportParser.parse("not json"), .failure(.invalidJSON))
    }

    func testRejectsObjectWithoutMatrix() {
        XCTAssertEqual(PuzzleImportParser.parse("{\"rows\": 5}"), .failure(.invalidJSON))
    }

    func testRejectsMatrixSmallerThanFive() {
        XCTAssertEqual(
            PuzzleImportParser.parse("[[1,0],[0,1]]"),
            .failure(.tooFewLines)
        )
    }

    func testRejectsMatrixLargerThanForty() throws {
        let matrix = Array(repeating: Array(repeating: 1, count: 5), count: 45)
        let data = try JSONEncoder().encode(matrix)

        XCTAssertEqual(PuzzleImportParser.parse(data), .failure(.tooManyLines))
    }

    func testRejectsNonMultipleOfFiveDimensions() throws {
        let matrix = Array(repeating: Array(repeating: 1, count: 5), count: 6)
        let data = try JSONEncoder().encode(matrix)

        XCTAssertEqual(PuzzleImportParser.parse(data), .failure(.notMultipleOfFive))
    }

    func testRejectsRaggedMatrix() {
        XCTAssertEqual(
            PuzzleImportParser.parse("[[1,0,1,0,1],[1,0],[1,0,1,0,1],[1,0,1,0,1],[1,0,1,0,1]]"),
            .failure(.raggedRows)
        )
    }

    func testRejectsNonBinaryValues() {
        let rows = "[1,0,2,0,1]," + Array(repeating: "[1,1,1,1,1]", count: 4).joined(separator: ",")

        XCTAssertEqual(PuzzleImportParser.parse("[\(rows)]"), .failure(.nonBinaryValues))
    }

    // MARK: - iOS PuzzleSet sources

    private func puzzleSetData(_ entries: [(String, [[Int]])], setName: String = "Testing") throws -> Data {
        let puzzles = entries.map { name, matrix -> [String: Any] in
            ["id": "testing_\(name.lowercased())", "name": name, "difficulty": "medium", "solution": matrix]
        }
        return try JSONSerialization.data(withJSONObject: ["setName": setName, "puzzles": puzzles])
    }

    func testParsesIOSPuzzleSet() throws {
        let data = try puzzleSetData([("Mouse", validMatrix)])

        XCTAssertEqual(PuzzleImportParser.parse(data), .success(validMatrix))
    }

    func testCarriesNamesThroughFromAPuzzleSet() throws {
        let other = (0..<5).map { row in (0..<5).map { $0 == (4 - row) ? 1 : 0 } }
        let data = try puzzleSetData([("Mouse", validMatrix), ("Duck", other)])

        let result = try XCTUnwrap(try? PuzzleImportParser.parsePuzzles(data).get())

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.map(\.name), ["Mouse", "Duck"])
        XCTAssertEqual(result.map(\.matrix), [validMatrix, other])
    }

    func testRejectsAPuzzleSetWithNoPuzzles() throws {
        let data = try JSONSerialization.data(withJSONObject: ["setName": "Testing", "puzzles": []])

        XCTAssertEqual(PuzzleImportParser.parsePuzzles(data), .failure(.emptySet))
    }

    func testRejectsTheWholeSetWhenOnePuzzleIsInvalid() throws {
        // All-or-nothing: a bad entry must not import as a silent subset.
        let ragged = [[1, 0, 1, 0, 1], [1, 0]]
        let data = try puzzleSetData([("Good", validMatrix), ("Bad", ragged)])

        XCTAssertEqual(PuzzleImportParser.parsePuzzles(data), .failure(.raggedRows))
    }

    func testBareMatrixCarriesNoName() throws {
        let data = try JSONEncoder().encode(validMatrix)

        let result = try XCTUnwrap(try? PuzzleImportParser.parsePuzzles(data).get())

        XCTAssertEqual(result.count, 1)
        XCTAssertNil(result[0].name)
    }

    func testCreatorExportCarriesItsName() throws {
        let export: [String: Any] = ["name": "marmot_5x5", "matrix": validMatrix]
        let data = try JSONSerialization.data(withJSONObject: export)

        let result = try XCTUnwrap(try? PuzzleImportParser.parsePuzzles(data).get())

        XCTAssertEqual(result[0].name, "marmot_5x5")
    }

    func testCreatorExportCarriesItsMetadata() throws {
        let json = """
        {"name": "marmot_5x5", "matrix": \(validMatrix),
         "metadata": {"createdBy": "Original puzzle design", "sourceNumber": 2, "unsureCells": 0,
                      "aspectDistortionPercent": 4.2, "reviewed": true, "tags": ["animal", null]}}
        """

        let result = try XCTUnwrap(try? PuzzleImportParser.parsePuzzles(json).get())

        XCTAssertEqual(result[0].metadata, [
            "createdBy": .string("Original puzzle design"),
            "sourceNumber": .integer(2),
            "unsureCells": .integer(0),
            "aspectDistortionPercent": .number(4.2),
            "reviewed": .bool(true),
            "tags": .array([.string("animal"), .null]),
        ])
    }

    func testBareMatrixAndPuzzleSetCarryNoMetadata() throws {
        let bare = try JSONEncoder().encode(validMatrix)
        let set = try JSONSerialization.data(withJSONObject: [
            "setName": "Testing",
            "puzzles": [["id": "testing_x", "name": "X", "difficulty": "medium", "solution": validMatrix]],
        ])

        XCTAssertNil(try PuzzleImportParser.parsePuzzles(bare).get()[0].metadata)
        XCTAssertNil(try PuzzleImportParser.parsePuzzles(set).get()[0].metadata)
    }
}
