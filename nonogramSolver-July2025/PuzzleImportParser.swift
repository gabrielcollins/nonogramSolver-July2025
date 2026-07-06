import Foundation

/// Parses puzzle JSON produced by nonogramImageCreator (see its
/// docs/json-format.md): either the full export object, whose "matrix" key
/// holds a 0/1 grid, or a bare 0/1 matrix (the mirror of the gridJSON
/// export). Clues in the file are ignored; the app re-derives them from the
/// matrix, exactly as tap-editing does.
struct PuzzleImportParser {
    enum ParseError: LocalizedError, Equatable {
        case invalidJSON
        case tooFewLines
        case tooManyLines
        case notMultipleOfFive
        case raggedRows
        case nonBinaryValues

        var errorDescription: String? {
            switch self {
            case .invalidJSON:
                return "Not a puzzle JSON file (expected a matrix or an export with a \"matrix\" key)"
            case .tooFewLines:
                return "Matrix must be at least 5x5"
            case .tooManyLines:
                return "Matrix cannot exceed 40x40"
            case .notMultipleOfFive:
                return "Matrix dimensions must be multiples of 5"
            case .raggedRows:
                return "Matrix rows must all have the same length"
            case .nonBinaryValues:
                return "Matrix values must be 0 or 1"
            }
        }
    }

    private struct CreatorExport: Decodable {
        let matrix: [[Int]]
    }

    static func parse(_ data: Data) -> Result<[[Int]], ParseError> {
        let decoder = JSONDecoder()
        let matrix: [[Int]]
        if let bare = try? decoder.decode([[Int]].self, from: data) {
            matrix = bare
        } else if let export = try? decoder.decode(CreatorExport.self, from: data) {
            matrix = export.matrix
        } else {
            return .failure(.invalidJSON)
        }
        return validate(matrix)
    }

    static func parse(_ string: String) -> Result<[[Int]], ParseError> {
        guard let data = string.data(using: .utf8) else { return .failure(.invalidJSON) }
        return parse(data)
    }

    private static func validate(_ matrix: [[Int]]) -> Result<[[Int]], ParseError> {
        let columns = matrix.first?.count ?? 0
        guard matrix.allSatisfy({ $0.count == columns }) else { return .failure(.raggedRows) }
        for count in [matrix.count, columns] {
            guard count >= 5 else { return .failure(.tooFewLines) }
            guard count <= 40 else { return .failure(.tooManyLines) }
            guard count % 5 == 0 else { return .failure(.notMultipleOfFive) }
        }
        guard matrix.allSatisfy({ $0.allSatisfy { $0 == 0 || $0 == 1 } }) else {
            return .failure(.nonBinaryValues)
        }
        return .success(matrix)
    }
}
