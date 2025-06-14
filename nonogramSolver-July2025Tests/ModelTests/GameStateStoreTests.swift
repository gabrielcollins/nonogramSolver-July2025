import XCTest
import Foundation
@testable import nonogramSolver_July2025

final class GameStateStoreTests: XCTestCase {
    @MainActor
    func testSaveAndLoadRoundTrip() async throws {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)

        let grid = PuzzleGrid(rows: 1, columns: 1)
        let state = GameState(grid: grid, rowCluesBySize: [1: [[]]], columnCluesBySize: [1: [[]]])
        let store = GameStateStore()

        await store.save(state)
        let loaded = await store.load()

        XCTAssertEqual(loaded?.grid.rows, state.grid.rows)
        XCTAssertEqual(loaded?.grid.columns, state.grid.columns)
    }
}
