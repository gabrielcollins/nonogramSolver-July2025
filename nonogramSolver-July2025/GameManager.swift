import SwiftUI

@MainActor
class GameManager: ObservableObject {
    @Published private(set) var grid: PuzzleGrid
    @Published var rowClues: [[Int]]
    @Published var columnClues: [[Int]]

    private let store = GameStateStore()

    init() {
        self.grid = PuzzleGrid(rows: 20, columns: 15)
        self.rowClues = Array(repeating: [], count: grid.rows)
        self.columnClues = Array(repeating: [], count: grid.columns)
    }

    func load() async {
        if let state = await store.load() {
            self.grid = state.grid
            self.rowClues = state.rowClues
            self.columnClues = state.columnClues
        }
    }

    func save() async {
        let state = GameState(grid: grid, rowClues: rowClues, columnClues: columnClues)
        await store.save(state)
    }

    func set(rows: Int, columns: Int) {
        grid = PuzzleGrid(rows: rows, columns: columns)
        rowClues = Array(repeating: [], count: rows)
        columnClues = Array(repeating: [], count: columns)
        Task { await save() }
    }

    func tap(row: Int, column: Int) {
        guard row < grid.rows, column < grid.columns else { return }
        let current = grid.tiles[row][column]
        let next: TileState
        switch current {
        case .unmarked:
            next = .filled
        case .filled:
            next = .empty
        case .empty:
            next = .unmarked
        }
        grid.tiles[row][column] = next
        Task { await save() }
    }

    func updateRowClue(row: Int, string: String) {
        rowClues[row] = string.split(separator: " ").compactMap { Int($0) }
        Task { await save() }
    }

    func updateColumnClue(column: Int, string: String) {
        columnClues[column] = string.split(separator: " ").compactMap { Int($0) }
        Task { await save() }
    }

    func autoSolve() {
        // stub
    }

    func stepSolve() {
        // stub
    }
}
