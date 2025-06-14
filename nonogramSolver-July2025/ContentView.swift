import SwiftUI

struct ContentView: View {
    @StateObject private var manager: GameManager
    @State private var rowInputs: [String] = []
    @State private var columnInputs: [String] = []

    init(manager: GameManager) {
        _manager = StateObject(wrappedValue: manager)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                NonogramGridView(manager: manager)
                
                VStack(spacing: 15) {
                    // Grid controls and solve buttons
                    VStack(spacing: 10) {
                        HStack(spacing: 20) {
                            // Grid size controls
                            HStack(spacing: 15) {
                                VStack {
                                    Text("Rows")
                                        .font(.caption)
                                    Picker("Rows", selection: Binding(
                                        get: { manager.grid.rows },
                                        set: { manager.set(rows: $0, columns: manager.grid.columns) }
                                    )) {
                                        ForEach(Array(stride(from: 5, through: 40, by: 5)), id: \.self) { value in
                                            Text("\(value)").tag(value)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                                
                                VStack {
                                    Text("Columns")
                                        .font(.caption)
                                    Picker("Columns", selection: Binding(
                                        get: { manager.grid.columns },
                                        set: { manager.set(rows: manager.grid.rows, columns: $0) }
                                    )) {
                                        ForEach(Array(stride(from: 5, through: 40, by: 5)), id: \.self) { value in
                                            Text("\(value)").tag(value)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                            }
                            
                            Spacer()
                            
                            // Solve buttons
                            HStack(spacing: 10) {
                                Button("Auto Solve") { 
                                    manager.autoSolve() 
                                }
                                .buttonStyle(.borderedProminent)
                                
                                Button("Step Solve") { 
                                    manager.stepSolve() 
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                    
                    // Clue input section
                    VStack(spacing: 10) {
                        Text("Clue Input")
                            .font(.headline)
                        
                        HStack(alignment: .top) {
                            ScrollView {
                                VStack(alignment: .leading) {
                                    Text("Row Clues:")
                                        .font(.subheadline)
                                    ForEach(0..<manager.grid.rows, id: \.self) { row in
                                        HStack {
                                            Text("R\(row+1):")
                                                .frame(width: 30, alignment: .leading)
                                            TextField("e.g. 2 1", text: $rowInputs[row])
                                                .textFieldStyle(.roundedBorder)
                                                .onSubmit { manager.updateRowClue(row: row, string: rowInputs[row]) }
                                        }
                                    }
                                }
                            }

                            ScrollView {
                                VStack(alignment: .leading) {
                                    Text("Column Clues:")
                                        .font(.subheadline)
                                    ForEach(0..<manager.grid.columns, id: \.self) { column in
                                        HStack {
                                            Text("C\(column+1):")
                                                .frame(width: 30, alignment: .leading)
                                            TextField("e.g. 1 3", text: $columnInputs[column])
                                                .textFieldStyle(.roundedBorder)
                                                .onSubmit { manager.updateColumnClue(column: column, string: columnInputs[column]) }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
            .navigationTitle("Nonogram Solver")
            .onAppear(perform: syncInputs)
            .onChange(of: manager.grid.rows) { _ in syncInputs() }
            .onChange(of: manager.grid.columns) { _ in syncInputs() }
        }
    }

    private func syncInputs() {
        rowInputs = manager.rowClues.map { $0.map(String.init).joined(separator: " ") }
        columnInputs = manager.columnClues.map { $0.map(String.init).joined(separator: " ") }
    }
}

#Preview {
    ContentView(manager: GameManager())
}
