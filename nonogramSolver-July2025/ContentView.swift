import SwiftUI

struct ContentView: View {
    @StateObject private var manager: GameManager

    init(manager: GameManager) {
        _manager = StateObject(wrappedValue: manager)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                NonogramGridView(manager: manager)
                
                VStack(spacing: 10) {
                    Text("Clue Input")
                        .font(.headline)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Row Clues:")
                                .font(.subheadline)
                            ForEach(0..<min(5, manager.grid.rows), id: \.self) { row in
                                HStack {
                                    Text("R\(row+1):")
                                        .frame(width: 30, alignment: .leading)
                                    TextField("e.g. 2 1", text: Binding(
                                        get: { manager.rowClues[row].map(String.init).joined(separator: " ") },
                                        set: { manager.updateRowClue(row: row, string: $0) }
                                    ))
                                    .textFieldStyle(.roundedBorder)
                                }
                            }
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Column Clues:")
                                .font(.subheadline)
                            ForEach(0..<min(5, manager.grid.columns), id: \.self) { column in
                                HStack {
                                    Text("C\(column+1):")
                                        .frame(width: 30, alignment: .leading)
                                    TextField("e.g. 1 3", text: Binding(
                                        get: { manager.columnClues[column].map(String.init).joined(separator: " ") },
                                        set: { manager.updateColumnClue(column: column, string: $0) }
                                    ))
                                    .textFieldStyle(.roundedBorder)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
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
