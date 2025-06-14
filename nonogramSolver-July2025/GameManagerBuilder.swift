import SwiftUI

struct GameManagerBuilder {
    let store: GameStateStoring
    let loader: PuzzleLoading

    init(store: GameStateStoring = GameStateStore(), loader: PuzzleLoading = PuzzleService()) {
        self.store = store
        self.loader = loader
    }

    @MainActor
    func build() async -> GameManager {
        let manager = GameManager(store: store)
        await manager.load()
        if manager.rowClues.allSatisfy({ $0.isEmpty }),
           let puzzle = loader.loadPuzzle() {
            manager.set(rows: puzzle.grid.rows, columns: puzzle.grid.columns)
            manager.rowClues = puzzle.rowCluesBySize[puzzle.grid.rows] ?? Array(repeating: [Int](), count: puzzle.grid.rows)
            manager.columnClues = puzzle.columnCluesBySize[puzzle.grid.columns] ?? Array(repeating: [Int](), count: puzzle.grid.columns)
        }
        return manager
    }
}
