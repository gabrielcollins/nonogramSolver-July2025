import SwiftUI

struct ContentView: View {
    @StateObject private var manager: GameManager

    init(manager: GameManager) {
        _manager = StateObject(wrappedValue: manager)
    }

    var body: some View {
        NavigationStack {
            VStack {
                NonogramGridView(manager: manager)
                ClueEntryView(manager: manager)
            }
            .padding()
            .navigationTitle("Nonogram Solver")
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Picker("Rows", selection: Binding(
                        get: { manager.grid.rows },
                        set: { manager.set(rows: $0, columns: manager.grid.columns) }
                    )) {
                        ForEach(Array(stride(from: 5, through: 40, by: 5)), id: \.self) { value in
                            Text("\(value)").tag(value)
                        }
                    }
                    Picker("Columns", selection: Binding(
                        get: { manager.grid.columns },
                        set: { manager.set(rows: manager.grid.rows, columns: $0) }
                    )) {
                        ForEach(Array(stride(from: 5, through: 40, by: 5)), id: \.self) { value in
                            Text("\(value)").tag(value)
                        }
                    }
                }
                ToolbarItemGroup(placement: .automatic) {
                    Button("Auto Solve") { manager.autoSolve() }
                    Button("Step Solve") { manager.stepSolve() }
                }
            }
        }
    }
}

#Preview {
    ContentView(manager: GameManager())
}
