import XCTest
@testable import nonogramSolver_July2025

private struct SimpleValue: Codable, Equatable {
    let name: String
}

final class FlatFileControllerTests: XCTestCase {
    func testSaveAndLoadValue() async throws {
        let controller = FlatFileController()
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)

        let value = SimpleValue(name: "test")
        let fileName = "simple_value.json"
        try await controller.save(value, to: fileName)
        let loaded: SimpleValue = try await controller.load(fileName, as: SimpleValue.self)
        XCTAssertEqual(loaded, value)
    }
}
