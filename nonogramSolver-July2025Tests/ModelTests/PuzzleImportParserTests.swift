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
}
