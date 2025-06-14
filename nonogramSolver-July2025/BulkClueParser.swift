import Foundation

struct BulkClueParser {
    enum ParseError: LocalizedError, Equatable {
        case invalidEncoding
        case invalidJSON
        case tooFew
        case tooMany
        case notMultipleOfFive
        case nonPositiveNumbers

        var errorDescription: String? {
            switch self {
            case .invalidEncoding:
                return "Unable to decode text"
            case .invalidJSON:
                return "Invalid JSON"
            case .tooFew:
                return "JSON must contain at least 5 arrays"
            case .tooMany:
                return "JSON cannot exceed 40 arrays"
            case .notMultipleOfFive:
                return "JSON does not contain a multiple of 5"
            case .nonPositiveNumbers:
                return "Clue numbers must all be positive"
            }
        }
    }

    static func parse(_ string: String) -> Result<[[Int]], ParseError> {
        // Remove common whitespace characters so pretty printed JSON still parses
        let cleaned = string.filter { !$0.isWhitespace }
        guard let data = cleaned.data(using: .utf8) else { return .failure(.invalidEncoding) }
        do {
            let clues = try JSONDecoder().decode([[Int]].self, from: data)
            guard clues.count >= 5 else { return .failure(.tooFew) }
            guard clues.count <= 40 else { return .failure(.tooMany) }
            guard clues.count % 5 == 0 else { return .failure(.notMultipleOfFive) }
            guard clues.allSatisfy({ $0.allSatisfy { $0 > 0 } }) else { return .failure(.nonPositiveNumbers) }
            return .success(clues)
        } catch {
            return .failure(.invalidJSON)
        }
    }
}
