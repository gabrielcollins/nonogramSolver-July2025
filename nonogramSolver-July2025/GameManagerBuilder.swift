import SwiftUI

struct GameManagerBuilder {
    func build() async -> GameManager {
        let manager = GameManager()
        await manager.load()
        return manager
    }
}
