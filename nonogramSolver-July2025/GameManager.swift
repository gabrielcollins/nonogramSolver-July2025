import SwiftUI
import AppKit

@MainActor
class GameManager: ObservableObject {
    @Published private(set) var grid: PuzzleGrid
    @Published var rowClues: [[Int]]
    @Published var columnClues: [[Int]]
    @Published var highlightedRow: Int?
    @Published var highlightedColumn: Int?
    // Row or column currently highlighted due to missing clues
    @Published var errorRow: Int?
    @Published var errorColumn: Int?
    @Published var contradictionRow: Int?
    @Published var contradictionColumn: Int?
    @Published var contradictionEncountered: Bool = false
    @Published var solvingStepCount: Int = 0
    @Published var lastSolvedClues: String?
    @Published var unsolvableByStep: Bool = false
    private var progressMadeDuringStep: Bool = false
    /// Returns `true` when no tiles remain in the `.unmarked` state.
    var isPuzzleSolved: Bool {
        !grid.tiles.flatMap { $0 }.contains(.unmarked)
    }

    /// JSON representation of the current grid using `1` for `.filled` tiles and
    /// `0` for both `.empty` and `.unmarked`. The result formats each row on a
    /// single line like:
    /// ````
    /// [
    ///     [0,1,1],
    ///     [1,0,0]
    /// ]
    /// ````
    var gridJSON: String {
        let intGrid = grid.tiles.map { row in
            row.map { $0 == .filled ? 1 : 0 }
        }
        let rowStrings = intGrid.map { row in
            "    [" + row.map(String.init).joined(separator: ",") + "]"
        }
        return "[\n" + rowStrings.joined(separator: ",\n") + "\n]"
    }

    /// JSON representation of the current row and column clues. The output is
    /// pretty printed and has the form:
    /// ```
    /// {
    ///   "rowClues": [[1],[2]],
    ///   "columnClues": [[1],[2]]
    /// }
    /// ```
    var cluesJSON: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let object = ["rowClues": rowClues, "columnClues": columnClues]
        guard let data = try? encoder.encode(object),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    /// Returns `true` when every row and every column contains at least one
    /// clue number.
    var hasCompleteClues: Bool {
        rowClues.allSatisfy { !$0.isEmpty } && columnClues.allSatisfy { !$0.isEmpty }
    }

    /// Copies the grid JSON representation to the system pasteboard.
    func copyGridToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(gridJSON, forType: .string)
    }

    /// Copies the clues JSON representation to the system pasteboard.
    func copyCluesToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(cluesJSON, forType: .string)
    }
    private var solvingRows = true
    private var rowCluesBySize: [Int: [[Int]]]
    private var columnCluesBySize: [Int: [[Int]]]

    private let store: GameStateStoring

    init(grid: PuzzleGrid, rowClues: [[Int]], columnClues: [[Int]], store: GameStateStoring,
         rowCluesBySize: [Int: [[Int]]] = [:], columnCluesBySize: [Int: [[Int]]] = [:]) {
        self.grid = grid
        self.rowClues = rowClues
        self.columnClues = columnClues
        self.errorRow = nil
        self.errorColumn = nil
        self.contradictionRow = nil
        self.contradictionColumn = nil
        self.contradictionEncountered = false
        self.rowCluesBySize = rowCluesBySize
        self.columnCluesBySize = columnCluesBySize
        self.store = store
        self.lastSolvedClues = "R\(grid.rows)"
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
        lastSolvedClues = "R\(rows)"
        
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
        // Update the clues for the affected row and column
        rowClues[row] = clues(from: grid.tiles[row])
        let columnStates = grid.tiles.map { $0[column] }
        columnClues[column] = clues(from: columnStates)
        rowCluesBySize[grid.rows] = rowClues
        columnCluesBySize[grid.columns] = columnClues
        Task { await save() }
    }

    func updateRowClue(row: Int, string: String) {
        guard row < rowClues.count else { return }
        rowClues[row] = string.split(separator: " ").compactMap { Int($0) }
        rowCluesBySize[grid.rows] = rowClues
        if row == contradictionRow {
            contradictionRow = nil
            contradictionEncountered = false
        }
        Task { await save() }
    }

    func updateColumnClue(column: Int, string: String) {
        guard column < columnClues.count else { return }
        columnClues[column] = string.split(separator: " ").compactMap { Int($0) }
        columnCluesBySize[grid.columns] = columnClues
        if column == contradictionColumn {
            contradictionColumn = nil
            contradictionEncountered = false
        }
        Task { await save() }
    }

    func clearRowClues() {
        rowClues = Array(repeating: [], count: grid.rows)
        rowCluesBySize[grid.rows] = rowClues
        contradictionRow = nil
        contradictionEncountered = false
        Task { await save() }
    }

    func clearColumnClues() {
        columnClues = Array(repeating: [], count: grid.columns)
        columnCluesBySize[grid.columns] = columnClues
        contradictionColumn = nil
        contradictionEncountered = false
        Task { await save() }
    }

    func loadRowClues(_ clues: [[Int]]) {
        set(rows: clues.count, columns: grid.columns)
        rowClues = clues
        rowCluesBySize[grid.rows] = clues
        Task { await save() }
    }

    func loadColumnClues(_ clues: [[Int]]) {
        set(rows: grid.rows, columns: clues.count)
        columnClues = clues
        columnCluesBySize[grid.columns] = clues
        Task { await save() }
    }

    func clearBoard() {
        grid = PuzzleGrid(rows: grid.rows, columns: grid.columns)
        solvingRows = true
        highlightedRow = grid.rows - 1
        lastSolvedClues = "R\(grid.rows)"
        highlightedColumn = nil
        errorRow = nil
        errorColumn = nil
        contradictionRow = nil
        contradictionColumn = nil
        contradictionEncountered = false
        unsolvableByStep = false
        solvingStepCount = 0
        Task { await save() }
    }

    func autoSolve() async {
        while !isPuzzleSolved &&
              !contradictionEncountered &&
              !unsolvableByStep {
            stepSolve()
            if isPuzzleSolved || contradictionEncountered || unsolvableByStep {
                break
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
    }

    func stepSolve() {
        guard !isPuzzleSolved else { return }
        guard !contradictionEncountered else { return }
        guard !unsolvableByStep else { return }
        progressMadeDuringStep = false
        if solvingRows {
            if let errorRow = errorRow {
                self.errorRow = nil
                highlightedRow = previousUnsolvedRow(before: errorRow)
                if highlightedRow == nil {
                    solvingRows = false
                    highlightedColumn = nextUnsolvedColumn(after: -1)
                }
                return
            }

            if highlightedRow == nil {
                highlightedRow = previousUnsolvedRow(before: grid.rows)
            }

            guard let row = highlightedRow, row >= 0, row < grid.rows else { return }

            if rowClues[row].isEmpty {
                errorRow = row
                return
            }

            if !solveRow(row) { return }
            solvingStepCount += 1
            if progressMadeDuringStep {
                lastSolvedClues = "R\(row + 1)"
                unsolvableByStep = false
            }

            highlightedRow = previousUnsolvedRow(before: row)
            if highlightedRow == nil {
                solvingRows = false
                highlightedColumn = nextUnsolvedColumn(after: -1)
            } else if !progressMadeDuringStep, let next = highlightedRow, lastSolvedClues == "R\(next + 1)" {
                unsolvableByStep = true
            }
        } else {
            if let errorColumn = errorColumn {
                self.errorColumn = nil
                highlightedColumn = nextUnsolvedColumn(after: errorColumn)
                if highlightedColumn == nil {
                    solvingRows = true
                    highlightedRow = previousUnsolvedRow(before: grid.rows)
                }
                return
            }

            if highlightedColumn == nil {
                highlightedColumn = nextUnsolvedColumn(after: -1)
            }

            guard let column = highlightedColumn, column >= 0, column < grid.columns else { return }

            if columnClues[column].isEmpty {
                errorColumn = column
                return
            }

            if !solveColumn(column) { return }
            solvingStepCount += 1
            if progressMadeDuringStep {
                lastSolvedClues = "C\(column + 1)"
                unsolvableByStep = false
            }

            highlightedColumn = nextUnsolvedColumn(after: column)
            if highlightedColumn == nil {
                solvingRows = true
                highlightedRow = previousUnsolvedRow(before: grid.rows)
            } else if !progressMadeDuringStep, let next = highlightedColumn, lastSolvedClues == "C\(next + 1)" {
                unsolvableByStep = true
            }
        }
    }

    private func isRowSolved(_ row: Int) -> Bool {
        guard row >= 0 && row < grid.rows else { return true }
        return !grid.tiles[row].contains(.unmarked)
    }

    private func isColumnSolved(_ column: Int) -> Bool {
        guard column >= 0 && column < grid.columns else { return true }
        for row in 0..<grid.rows {
            if grid.tiles[row][column] == .unmarked { return false }
        }
        return true
    }

    private func previousUnsolvedRow(before index: Int) -> Int? {
        var i = index - 1
        while i >= 0 {
            if !isRowSolved(i) { return i }
            i -= 1
        }
        return nil
    }

    private func nextUnsolvedColumn(after index: Int) -> Int? {
        var i = index + 1
        while i < grid.columns {
            if !isColumnSolved(i) { return i }
            i += 1
        }
        return nil
    }

    // MARK: - Line Solving

    private func solveRow(_ row: Int) -> Bool {
        guard row < grid.rows else { return true }
        let current = grid.tiles[row]
        let clues = rowClues[row]
        let permutations = generateLinePermutations(currentLineState: current, clues: clues)
        guard !permutations.isEmpty else {
            contradictionRow = row
            contradictionEncountered = true
            return false
        }

        for column in 0..<current.count {
            let states = Set(permutations.map { $0[column] })
            if states.count == 1, let state = states.first {
                if grid.tiles[row][column] != state {
                    grid.tiles[row][column] = state
                    progressMadeDuringStep = true
                }
            }
        }
        return true
    }

    private func solveColumn(_ column: Int) -> Bool {
        guard column < grid.columns else { return true }
        let current = grid.tiles.map { $0[column] }
        let clues = columnClues[column]
        let permutations = generateLinePermutations(currentLineState: current, clues: clues)
        guard !permutations.isEmpty else {
            contradictionColumn = column
            contradictionEncountered = true
            return false
        }

        for row in 0..<current.count {
            let states = Set(permutations.map { $0[row] })
            if states.count == 1, let state = states.first {
                if grid.tiles[row][column] != state {
                    grid.tiles[row][column] = state
                    progressMadeDuringStep = true
                }
            }
        }
        return true
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

    private func clues(from states: [TileState]) -> [Int] {
        var result: [Int] = []
        var count = 0
        for state in states {
            if state == .filled {
                count += 1
            } else if count > 0 {
                result.append(count)
                count = 0
            }
        }
        if count > 0 {
            result.append(count)
        }
        return result
    }
}
