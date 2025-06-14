import SwiftUI

@MainActor
class GameManager: ObservableObject {
    @Published private(set) var grid: PuzzleGrid
    @Published var rowClues: [[Int]]
    @Published var columnClues: [[Int]]

    private let store: GameStateStoring
    private var states = GameStateCollection()

    private var currentKey: String { "\(grid.rows)x\(grid.columns)" }

    init(grid: PuzzleGrid, rowClues: [[Int]], columnClues: [[Int]], store: GameStateStoring) {
        self.grid = grid
        self.rowClues = rowClues
        self.columnClues = columnClues
        self.store = store
        self.states.states[currentKey] = GameState(grid: grid, rowClues: rowClues, columnClues: columnClues)
    }

    convenience init(store: GameStateStoring = GameStateStore()) {
        let rows = 20
        let columns = 15
        let grid = PuzzleGrid(rows: rows, columns: columns)
        let rowClues = Array(repeating: [Int](), count: rows)
        let columnClues = Array(repeating: [Int](), count: columns)
        self.init(grid: grid, rowClues: rowClues, columnClues: columnClues, store: store)
    }

    func load() async {
        states = await store.load()
        if let loaded = states.states[currentKey] {
            grid = loaded.grid
            rowClues = loaded.rowClues
            columnClues = loaded.columnClues
        } else {
            states.states[currentKey] = GameState(grid: grid, rowClues: rowClues, columnClues: columnClues)
        }
    }

    func save() async {
        states.states[currentKey] = GameState(grid: grid, rowClues: rowClues, columnClues: columnClues)
        await store.save(states)
    }

    func set(rows: Int, columns: Int) {
        // Save existing state
        states.states[currentKey] = GameState(grid: grid, rowClues: rowClues, columnClues: columnClues)

        let newKey = "\(rows)x\(columns)"
        if let existing = states.states[newKey] {
            grid = existing.grid
            rowClues = existing.rowClues
            columnClues = existing.columnClues
        } else {
            grid = PuzzleGrid(rows: rows, columns: columns)
            rowClues = Array(repeating: [Int](), count: rows)
            columnClues = Array(repeating: [Int](), count: columns)
        }
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
