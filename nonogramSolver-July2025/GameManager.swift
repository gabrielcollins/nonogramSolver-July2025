import SwiftUI

@MainActor
class GameManager: ObservableObject {
    @Published private(set) var grid: PuzzleGrid
    @Published var rowClues: [[Int]]
    @Published var columnClues: [[Int]]
    private var rowCluesBySize: [Int: [[Int]]]
    private var columnCluesBySize: [Int: [[Int]]]

    private let store: GameStateStoring

    init(grid: PuzzleGrid, rowClues: [[Int]], columnClues: [[Int]], store: GameStateStoring,
         rowCluesBySize: [Int: [[Int]]] = [:], columnCluesBySize: [Int: [[Int]]] = [:]) {
        self.grid = grid
        self.rowClues = rowClues
        self.columnClues = columnClues
        self.rowCluesBySize = rowCluesBySize
        self.columnCluesBySize = columnCluesBySize
        self.store = store
    }

    convenience init(store: GameStateStoring = GameStateStore()) {
        let rows = 20
        let columns = 15
        let grid = PuzzleGrid(rows: rows, columns: columns)
        let rowClues = Array(repeating: [Int](), count: rows)
        let columnClues = Array(repeating: [Int](), count: columns)
        let rowMap = [rows: rowClues]
        let columnMap = [columns: columnClues]
        self.init(grid: grid, rowClues: rowClues, columnClues: columnClues, store: store, rowCluesBySize: rowMap, columnCluesBySize: columnMap)
    }

    func load() async {
        if let state = await store.load() {
            self.grid = state.grid
            self.rowCluesBySize = state.rowCluesBySize
            self.columnCluesBySize = state.columnCluesBySize
            self.rowClues = state.rowCluesBySize[state.grid.rows] ?? Array(repeating: [Int](), count: state.grid.rows)
            self.columnClues = state.columnCluesBySize[state.grid.columns] ?? Array(repeating: [Int](), count: state.grid.columns)
        }
    }

    func save() async {
        rowCluesBySize[grid.rows] = rowClues
        columnCluesBySize[grid.columns] = columnClues
        let state = GameState(grid: grid, rowCluesBySize: rowCluesBySize, columnCluesBySize: columnCluesBySize)
        await store.save(state)
    }

    func set(rows: Int, columns: Int) {
        // Persist clues for current size
        rowCluesBySize[grid.rows] = rowClues
        columnCluesBySize[grid.columns] = columnClues

        grid = PuzzleGrid(rows: rows, columns: columns)

        if let savedRows = rowCluesBySize[rows] {
            rowClues = savedRows
        } else {
            rowClues = Array(repeating: [Int](), count: rows)
            rowCluesBySize[rows] = rowClues
        }

        if let savedColumns = columnCluesBySize[columns] {
            columnClues = savedColumns
        } else {
            columnClues = Array(repeating: [Int](), count: columns)
            columnCluesBySize[columns] = columnClues
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
        rowCluesBySize[grid.rows] = rowClues
        Task { await save() }
    }

    func updateColumnClue(column: Int, string: String) {
        columnClues[column] = string.split(separator: " ").compactMap { Int($0) }
        columnCluesBySize[grid.columns] = columnClues
        Task { await save() }
    }

    func autoSolve() {
        // stub
    }

    func stepSolve() {
        // stub
    }
}
