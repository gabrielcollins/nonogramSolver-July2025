import SwiftUI

@MainActor
class GameManager: ObservableObject {
    @Published private(set) var grid: PuzzleGrid
    @Published var rowClues: [[Int]]
    @Published var columnClues: [[Int]]
    @Published var highlightedRow: Int?
    @Published var highlightedColumn: Int?
    @Published var solvingStepCount: Int = 0
    private var solvingRows = true
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
        // Don't do anything if the size hasn't changed
        if grid.rows == rows && grid.columns == columns {
            return
        }
        
        // Persist clues for current size before changing anything
        rowCluesBySize[grid.rows] = rowClues
        columnCluesBySize[grid.columns] = columnClues

        // Create new grid and clue arrays atomically
        let newGrid = PuzzleGrid(rows: rows, columns: columns)
        let newRowClues: [[Int]]
        let newColumnClues: [[Int]]
        
        if let savedRows = rowCluesBySize[rows] {
            newRowClues = savedRows
        } else {
            newRowClues = Array(repeating: [Int](), count: rows)
        }

        if let savedColumns = columnCluesBySize[columns] {
            newColumnClues = savedColumns
        } else {
            newColumnClues = Array(repeating: [Int](), count: columns)
        }
        
        // Update all state atomically to prevent race conditions
        // Use objectWillChange to ensure UI updates happen properly
        objectWillChange.send()
        
        grid = newGrid
        rowClues = newRowClues
        columnClues = newColumnClues
        
        // Update the dictionaries with the new arrays
        rowCluesBySize[rows] = newRowClues
        columnCluesBySize[columns] = newColumnClues

        Task { await save() }
    }

    func tap(row: Int, column: Int) {
        guard row < grid.rows, column < grid.columns,
              row < grid.tiles.count, 
              row >= 0 && column >= 0 && column < grid.tiles[row].count else { return }
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
        guard row < rowClues.count else { return }
        rowClues[row] = string.split(separator: " ").compactMap { Int($0) }
        rowCluesBySize[grid.rows] = rowClues
        Task { await save() }
    }

    func updateColumnClue(column: Int, string: String) {
        guard column < columnClues.count else { return }
        columnClues[column] = string.split(separator: " ").compactMap { Int($0) }
        columnCluesBySize[grid.columns] = columnClues
        Task { await save() }
    }

    func clearBoard() {
        grid = PuzzleGrid(rows: grid.rows, columns: grid.columns)
        solvingRows = true
        highlightedRow = grid.rows - 1
        highlightedColumn = nil
        solvingStepCount = 0
        Task { await save() }
    }

    func autoSolve() {
        // stub
    }

    func stepSolve() {
        if solvingRows {
            if highlightedRow == nil {
                highlightedRow = grid.rows - 1
            }

            guard let row = highlightedRow, row >= 0, row < grid.rows else { return }

            solveRow(row)
            solvingStepCount += 1

            if row > 0 {
                highlightedRow = row - 1
            } else {
                highlightedRow = nil
                solvingRows = false
                highlightedColumn = 0
            }
        } else {
            if highlightedColumn == nil {
                highlightedColumn = 0
            }

            guard let column = highlightedColumn, column >= 0, column < grid.columns else { return }

            solveColumn(column)
            solvingStepCount += 1

            if column < grid.columns - 1 {
                highlightedColumn = column + 1
            } else {
                highlightedColumn = nil
                solvingRows = true
                highlightedRow = grid.rows - 1
            }
        }
    }

    // MARK: - Line Solving

    private func solveRow(_ row: Int) {
        guard row < grid.rows else { return }
        let current = grid.tiles[row]
        let clues = rowClues[row]
        let permutations = generateLinePermutations(currentLineState: current, clues: clues)
        guard !permutations.isEmpty else { return }

        for column in 0..<current.count {
            let states = Set(permutations.map { $0[column] })
            if states.count == 1, let state = states.first {
                grid.tiles[row][column] = state
            }
        }
    }

    private func solveColumn(_ column: Int) {
        guard column < grid.columns else { return }
        let current = grid.tiles.map { $0[column] }
        let clues = columnClues[column]
        let permutations = generateLinePermutations(currentLineState: current, clues: clues)
        guard !permutations.isEmpty else { return }

        for row in 0..<current.count {
            let states = Set(permutations.map { $0[row] })
            if states.count == 1, let state = states.first {
                grid.tiles[row][column] = state
            }
        }
    }

    private func generateLinePermutations(currentLineState: [TileState], clues: [Int]) -> [[TileState]] {
        var results: [[TileState]] = []
        let length = currentLineState.count

        func helper(_ index: Int, _ clueIndex: Int, _ line: [TileState]) {
            if clueIndex == clues.count {
                var candidate = line
                for i in index..<length {
                    if currentLineState[i] == .filled { return }
                    if candidate[i] == .unmarked { candidate[i] = .empty }
                }
                results.append(candidate)
                return
            }

            let clueLength = clues[clueIndex]
            let remainingClues = clues.suffix(from: clueIndex + 1)
            let minRemaining = remainingClues.reduce(0, +) + max(0, remainingClues.count)
            guard index + clueLength + minRemaining <= length else { return }

            for start in index...(length - clueLength - minRemaining) {
                var newLine = line
                var valid = true
                for pos in index..<start {
                    if currentLineState[pos] == .filled { valid = false; break }
                    if newLine[pos] == .unmarked { newLine[pos] = .empty }
                }
                if !valid { continue }

                for i in 0..<clueLength {
                    let pos = start + i
                    if currentLineState[pos] == .empty { valid = false; break }
                    newLine[pos] = .filled
                }
                if !valid { continue }

                var nextIndex = start + clueLength
                if clueIndex < clues.count - 1 {
                    if nextIndex >= length { continue }
                    if currentLineState[nextIndex] == .filled { continue }
                    if newLine[nextIndex] == .unmarked { newLine[nextIndex] = .empty }
                    nextIndex += 1
                }

                helper(nextIndex, clueIndex + 1, newLine)
            }
        }

        helper(0, 0, currentLineState)
        return results.filter { candidate in
            for i in 0..<length {
                if currentLineState[i] != .unmarked && candidate[i] != currentLineState[i] {
                    return false
                }
            }
            return true
        }
    }
}
