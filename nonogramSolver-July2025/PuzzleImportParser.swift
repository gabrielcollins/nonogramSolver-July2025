import Foundation

/// Parses puzzle JSON from anywhere in the toolchain (see
/// nonogramImageCreator/docs/json-format.md):
///
/// - a bare 0/1 matrix,
/// - a creator export object, whose "matrix" key holds a 0/1 grid,
/// - an iOS game `PuzzleSet`, whose "puzzles" array holds one or more objects
///   keyed by "solution" — the same format this app now exports, so a puzzle
///   round-trips through the editor unchanged.
///
/// Clues in the file are ignored; the app re-derives them from the matrix,
/// exactly as tap-editing does.
///
/// Blank rows and columns are deliberately *not* rejected here. Import exists
/// to load a puzzle for repair, so the contract's no-blank-lines rule is
/// enforced on export instead, where it gates shipping.
struct PuzzleImportParser {
    /// One puzzle lifted out of a source file. `name` is carried through when
    /// the source format has one, so a set holding several puzzles can be
    /// presented for selection by name rather than by index.
    struct ImportedPuzzle: Equatable {
        let name: String?
        let matrix: [[Int]]
    }

    enum ParseError: LocalizedError, Equatable {
        case invalidJSON
        case tooFewLines
        case tooManyLines
        case notMultipleOfFive
        case raggedRows
        case nonBinaryValues
        case emptySet

        var errorDescription: String? {
            switch self {
            case .invalidJSON:
                return "Not a puzzle JSON file (expected a matrix, an export with a \"matrix\" key, or a puzzle set)"
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
            case .emptySet:
                return "Puzzle set contains no puzzles"
            }
        }
    }

    private struct CreatorExport: Decodable {
        let matrix: [[Int]]
        let name: String?
    }

    private struct PuzzleSetFile: Decodable {
        struct Entry: Decodable {
            let name: String?
            let solution: [[Int]]
        }

        let puzzles: [Entry]
    }

    /// Every puzzle in the source, validated. A set is all-or-nothing: one bad
    /// matrix fails the file rather than silently importing a subset, so a
    /// malformed entry cannot slip past unnoticed.
    static func parsePuzzles(_ data: Data) -> Result<[ImportedPuzzle], ParseError> {
        let decoder = JSONDecoder()
        let candidates: [ImportedPuzzle]

        if let bare = try? decoder.decode([[Int]].self, from: data) {
            candidates = [ImportedPuzzle(name: nil, matrix: bare)]
        } else if let set = try? decoder.decode(PuzzleSetFile.self, from: data) {
            guard !set.puzzles.isEmpty else { return .failure(.emptySet) }
            candidates = set.puzzles.map { ImportedPuzzle(name: $0.name, matrix: $0.solution) }
        } else if let export = try? decoder.decode(CreatorExport.self, from: data) {
            candidates = [ImportedPuzzle(name: export.name, matrix: export.matrix)]
        } else {
            return .failure(.invalidJSON)
        }

        for candidate in candidates {
            if case .failure(let error) = validate(candidate.matrix) {
                return .failure(error)
            }
        }
        return .success(candidates)
    }

    static func parsePuzzles(_ string: String) -> Result<[ImportedPuzzle], ParseError> {
        guard let data = string.data(using: .utf8) else { return .failure(.invalidJSON) }
        return parsePuzzles(data)
    }

    /// The first puzzle's matrix. Kept for callers that only ever deal with
    /// single-puzzle sources.
    static func parse(_ data: Data) -> Result<[[Int]], ParseError> {
        parsePuzzles(data).flatMap { puzzles in
            guard let first = puzzles.first else { return .failure(.emptySet) }
            return .success(first.matrix)
        }
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
