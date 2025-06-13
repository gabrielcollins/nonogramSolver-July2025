import XCTest
@testable import nonogramSolver_July2025

final class nonogramSolver_July2025Tests: XCTestCase {

    func testTileCycle() async {
        let manager = GameManager()
        manager.tap(row: 0, column: 0)
        XCTAssertEqual(manager.grid.tiles[0][0], .filled)
        manager.tap(row: 0, column: 0)
        XCTAssertEqual(manager.grid.tiles[0][0], .empty)
        manager.tap(row: 0, column: 0)
        XCTAssertEqual(manager.grid.tiles[0][0], .unmarked)
    }

    func testPersistence() async throws {
        let manager = GameManager()
        manager.tap(row: 0, column: 0)
        await manager.save()
        let newManager = GameManager()
        await newManager.load()
        XCTAssertEqual(newManager.grid.tiles[0][0], manager.grid.tiles[0][0])
    }
}
