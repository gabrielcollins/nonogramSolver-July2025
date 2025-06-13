import SwiftUI

struct GameManagerBuilder {
    @MainActor
    func build() async -> GameManager {
        let manager = GameManager()
        await manager.load()
        return manager
    }
}
