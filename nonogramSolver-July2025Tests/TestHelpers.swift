import Foundation
@testable import nonogramSolver_July2025

/// Simple in-memory store for testing persistence.
actor InMemoryGameStateStore: GameStateStoring {
    private var state: GameState?

    func save(_ state: GameState) async {
        self.state = state
    }

    func load() async -> GameState? {
        return state
    }
}

/// Helper loader that returns a preset puzzle.
struct MockPuzzleLoader: PuzzleLoading {
    let puzzle: GameState?
    func loadPuzzle() -> GameState? { puzzle }
}
