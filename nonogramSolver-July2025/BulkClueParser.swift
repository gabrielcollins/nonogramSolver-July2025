import Foundation

struct BulkClueParser {
    static func parse(_ string: String) -> [[Int]]? {
        // Remove common whitespace characters so pretty printed JSON still parses
        let cleaned = string.filter { !$0.isWhitespace }
        guard let data = cleaned.data(using: .utf8) else { return nil }
        do {
            let clues = try JSONDecoder().decode([[Int]].self, from: data)
            guard clues.count >= 5,
                  clues.count <= 40,
                  clues.count % 5 == 0,
                  clues.allSatisfy({ $0.allSatisfy { $0 > 0 } }) else {
                return nil
            }
            return clues
        } catch {
            return nil
        }
    }
}
