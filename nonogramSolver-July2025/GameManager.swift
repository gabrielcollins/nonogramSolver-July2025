import SwiftUI
import AppKit

enum AutoSolveSpeed: String, CaseIterable, Identifiable {
    case fastest = "Fastest"
    case medium = "Medium"
    case slow = "Slow"

    var id: String { rawValue }

    var delayNanoseconds: UInt64 {
        switch self {
        case .fastest: return 0
        case .medium: return 100_000_000
        case .slow: return 200_000_000
        }
    }
}

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
    @Published var unsolvableByStep: Bool = false
    private var progressMadeDuringStep: Bool = false
    private var progressMadeDuringSweep: Bool = false
    /// Returns `true` when no tiles remain in the `.unmarked` state.
    var isPuzzleSolved: Bool {
        !grid.tiles.flatMap { $0 }.contains(.unmarked)
    }

    /// Display name for the puzzle, used to build the exported `name` and
    /// `id`. The solver has no other notion of puzzle identity.
    @Published var puzzleName: String = ""

    /// The current grid as a 0/1 matrix, `1` for `.filled` and `0` for both
    /// `.empty` and `.unmarked`.
    var solutionMatrix: [[Int]] {
        grid.tiles.map { row in
            row.map { $0 == .filled ? 1 : 0 }
        }
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
        let rowStrings = solutionMatrix.map { row in
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

    // MARK: - iOS game export

    /// Set name written into the export, and the name the game builds its
    /// filename from (`PuzzleService.loadPuzzleSet` uses
    /// `"\(setName.lowercased()).json"`).
    static let exportSetName = "Testing"

    /// Solver effort expressed in full sweeps of the board, which is what
    /// makes it comparable across grid sizes: `solvingStepCount` counts one
    /// step per *line* solved, so a 20x20 needs 40 steps just to look at every
    /// line once, while a 10x10 needs 20.
    var solverSweeps: Double {
        let lines = grid.rows + grid.columns
        guard lines > 0 else { return 0 }
        return Double(solvingStepCount) / Double(lines)
    }

    /// Difficulty vocabulary, matching the puzzles already shipping in the
    /// game (`medium`, `difficult`) rather than introducing a synonym. The
    /// game itself only checks that the string is non-empty, so this is a
    /// consistency choice, not a decoding requirement.
    static let easyDifficulty = "easy"
    static let mediumDifficulty = "medium"
    static let difficultDifficulty = "difficult"

    /// Crude difficulty from how many sweeps the line solver needed, the
    /// measure the authoring workflow already uses.
    ///
    /// The thresholds are a starting calibration, not a law — the UI shows the
    /// raw step count and sweep figure alongside so they can be tuned against
    /// real puzzles. An unsolved board has no measurement to report and falls
    /// back to medium.
    var derivedDifficulty: String {
        guard isPuzzleSolved, solvingStepCount > 0 else { return Self.mediumDifficulty }
        switch solverSweeps {
        case ..<2.0: return Self.easyDifficulty
        case ..<3.5: return Self.mediumDifficulty
        default: return Self.difficultDifficulty
        }
    }

    /// `true` once the difficulty reflects a real solve rather than the
    /// fallback.
    var difficultyIsMeasured: Bool {
        isPuzzleSolved && solvingStepCount > 0
    }

    /// Lowercased underscore form of the puzzle name, matching the id style of
    /// the puzzles already shipping in the game (`testing_duck`).
    ///
    /// Pure string work, so it carries no actor isolation.
    nonisolated static func slug(_ value: String) -> String {
        let mapped = value.lowercased().map { character -> Character in
            character.isLetter || character.isNumber ? character : "_"
        }
        return String(mapped)
            .split(separator: "_", omittingEmptySubsequences: true)
            .joined(separator: "_")
    }

    /// Identifier written into the export, e.g. `testing_new_mouse`.
    var iosPuzzleID: String {
        let name = Self.slug(puzzleName)
        let set = Self.slug(Self.exportSetName)
        return name.isEmpty ? set : "\(set)_\(name)"
    }

    /// Rows and columns with no filled cell. The shared contract forbids these
    /// because the game's clue generator emits `[0]` for a blank line and the
    /// bulk clue parser rejects it, so they must not reach an export.
    var blankLines: (rows: [Int], columns: [Int]) {
        let matrix = solutionMatrix
        let rows = matrix.indices.filter { !matrix[$0].contains(1) }
        let columns = (0 ..< grid.columns).filter { column in
            !matrix.contains { $0[column] == 1 }
        }
        return (rows, columns)
    }

    /// Why an export is blocked, or `nil` when it is ready to write.
    var iosExportBlocker: String? {
        if puzzleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Name the puzzle before exporting"
        }
        let blanks = blankLines
        if !blanks.rows.isEmpty {
            return "Blank rows not allowed: \(blanks.rows.map(String.init).joined(separator: ", "))"
        }
        if !blanks.columns.isEmpty {
            return "Blank columns not allowed: \(blanks.columns.map(String.init).joined(separator: ", "))"
        }
        return nil
    }

    var canExportForIOS: Bool { iosExportBlocker == nil }

    /// The current puzzle as an iOS game `PuzzleSet` containing one puzzle.
    /// Clues are deliberately omitted: the game derives them from `solution`
    /// at load time, so storing them would be data that could drift out of
    /// agreement with the grid.
    var iosExportJSON: String {
        let name = puzzleName.trimmingCharacters(in: .whitespacesAndNewlines)
        let puzzle: [String: Any] = [
            "id": iosPuzzleID,
            "name": name,
            "difficulty": derivedDifficulty,
            "solution": solutionMatrix,
        ]
        let set: [String: Any] = [
            "setName": Self.exportSetName,
            "puzzles": [puzzle],
        ]
        guard let data = try? JSONSerialization.data(
            withJSONObject: set,
            options: [.prettyPrinted, .sortedKeys]
        ), let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    /// Default filename offered by the save panel.
    var iosExportFilename: String {
        let name = Self.slug(puzzleName)
        return name.isEmpty ? "puzzle" : name
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

    /// Replaces the board with an imported 0/1 matrix (already validated by
    /// `PuzzleImportParser`). Filled cells become `.filled`, empty cells stay
    /// `.unmarked` so the puzzle remains editable and solvable. All clues are
    /// re-derived from the matrix, exactly as tap-editing does.
    func importGrid(matrix: [[Int]]) {
        let rows = matrix.count
        let columns = matrix.first?.count ?? 0
        guard rows > 0, columns > 0 else { return }

        rowCluesBySize[grid.rows] = rowClues
        columnCluesBySize[grid.columns] = columnClues

        var newGrid = PuzzleGrid(rows: rows, columns: columns)
        for row in 0..<rows {
            for column in 0..<columns where matrix[row][column] == 1 {
                newGrid.tiles[row][column] = .filled
            }
        }

        grid = newGrid
        rowClues = grid.tiles.map { clues(from: $0) }
        columnClues = (0..<columns).map { column in
            clues(from: grid.tiles.map { $0[column] })
        }
        rowCluesBySize[rows] = rowClues
        columnCluesBySize[columns] = columnClues

        solvingRows = true
        progressMadeDuringSweep = false
        highlightedRow = nil
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

    func clearBoard() {
        grid = PuzzleGrid(rows: grid.rows, columns: grid.columns)
        solvingRows = true
        progressMadeDuringSweep = false
        highlightedRow = grid.rows - 1
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

    /// Stepping speed for auto-solve; tests use .fastest for determinism.
    @Published var autoSolveSpeed: AutoSolveSpeed = .slow

    func autoSolve() async {
        if unsolvableByStep { clearBoard() }
        while !isPuzzleSolved &&
              !contradictionEncountered &&
              !unsolvableByStep {
            stepSolve()
            if isPuzzleSolved || contradictionEncountered || unsolvableByStep {
                break
            }
            let delay = autoSolveSpeed.delayNanoseconds
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }
        }
    }

    /// Marks the end of one full sweep (every unsolved row, then every
    /// unsolved column). If no cell changed across the entire sweep, line
    /// logic is exhausted and the puzzle is beyond the simple solving level.
    private func completeSweep() {
        if !progressMadeDuringSweep && !isPuzzleSolved {
            unsolvableByStep = true
        }
        progressMadeDuringSweep = false
    }

    func stepSolve() {
        // "Beyond Simple Level" is a stop, not a dead end: solving again
        // restarts from a cleared board (clues are preserved) so the author
        // can hand-edit and re-verify.
        if unsolvableByStep { clearBoard() }
        guard !isPuzzleSolved else { return }
        guard !contradictionEncountered else { return }
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
                progressMadeDuringSweep = true
            }

            highlightedRow = previousUnsolvedRow(before: row)
            if highlightedRow == nil {
                solvingRows = false
                highlightedColumn = nextUnsolvedColumn(after: -1)
            }
        } else {
            if let errorColumn = errorColumn {
                self.errorColumn = nil
                highlightedColumn = nextUnsolvedColumn(after: errorColumn)
                if highlightedColumn == nil {
                    completeSweep()
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
                progressMadeDuringSweep = true
            }

            highlightedColumn = nextUnsolvedColumn(after: column)
            if highlightedColumn == nil {
                completeSweep()
                solvingRows = true
                highlightedRow = previousUnsolvedRow(before: grid.rows)
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
        switch LineSolver.solve(line: grid.tiles[row], clues: rowClues[row]) {
        case .contradiction:
            contradictionRow = row
            contradictionEncountered = true
            return false
        case .deduced(let line):
            for column in 0..<line.count where grid.tiles[row][column] != line[column] {
                grid.tiles[row][column] = line[column]
                progressMadeDuringStep = true
            }
            return true
        }
    }

    private func solveColumn(_ column: Int) -> Bool {
        guard column < grid.columns else { return true }
        let current = grid.tiles.map { $0[column] }
        switch LineSolver.solve(line: current, clues: columnClues[column]) {
        case .contradiction:
            contradictionColumn = column
            contradictionEncountered = true
            return false
        case .deduced(let line):
            for row in 0..<line.count where grid.tiles[row][column] != line[row] {
                grid.tiles[row][column] = line[row]
                progressMadeDuringStep = true
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
