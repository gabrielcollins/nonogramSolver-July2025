import Foundation

protocol GameStateStoring: Sendable {
    func save(_ collection: GameStateCollection) async
    func load() async -> GameStateCollection
}

protocol PuzzleLoading {
    func loadPuzzle() -> GameState?
}

actor FlatFileController {
    func url(for fileName: String) -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent(fileName)
    }

    func save<T: Encodable>(_ value: T, to file: String) throws {
        let data = try JSONEncoder().encode(value)
        let url = url(for: file)
        try data.write(to: url, options: [.atomic])
    }

    func load<T: Decodable>(_ file: String, as type: T.Type) throws -> T {
        let url = url(for: file)
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

actor GameStateStore: GameStateStoring {
    private let controller = FlatFileController()
    private let fileName = "gamestate.json"

    func save(_ collection: GameStateCollection) async {
        do {
            try await controller.save(collection, to: fileName)
        } catch {
            print("Failed to save state: \(error)")
        }
    }

    func load() async -> GameStateCollection {
        do {
            return try await controller.load(fileName, as: GameStateCollection.self)
        } catch {
            return GameStateCollection()
        }
    }
}

struct PuzzleService: PuzzleLoading {
    func loadPuzzle() -> GameState? {
        guard let url = Bundle.main.url(forResource: "testing", withExtension: "json") else {
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(GameState.self, from: data)
        } catch {
            return nil
        }
    }
}
