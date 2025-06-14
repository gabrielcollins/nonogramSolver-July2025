import Foundation

enum TileState: String, Codable {
    case filled
    case empty
    case unmarked
}

struct PuzzleGrid: Codable {
    var rows: Int
    var columns: Int
    var tiles: [[TileState]]

    init(rows: Int, columns: Int, fill: TileState = .unmarked) {
        self.rows = rows
        self.columns = columns
        self.tiles = Array(repeating: Array(repeating: fill, count: columns), count: rows)
    }
}

struct GameState: Codable {
    var grid: PuzzleGrid
    var rowCluesBySize: [Int: [[Int]]]
    var columnCluesBySize: [Int: [[Int]]]
}
