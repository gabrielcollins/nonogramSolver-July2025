import SwiftUI

struct ClueEntryView: View {
    @ObservedObject var manager: GameManager

    var body: some View {
        VStack(alignment: .leading) {
            Text("Row Clues")
            ForEach(0..<manager.grid.rows, id: \.self) { row in
                TextField("Row \(row)", text: Binding(
                    get: { 
                        guard row < manager.rowClues.count else { return "" }
                        return manager.rowClues[row].map(String.init).joined(separator: " ") 
                    },
                    set: { manager.updateRowClue(row: row, string: $0) }
                ))
                    .onSubmit {
                        guard row < manager.rowClues.count else { return }
                        manager.updateRowClue(row: row, string: manager.rowClues[row].map(String.init).joined(separator: " "))
                    }
                    .textFieldStyle(.roundedBorder)
            }
            Text("Column Clues")
            ForEach(0..<manager.grid.columns, id: \.self) { column in
                TextField("Col \(column)", text: Binding(
                    get: { 
                        guard column < manager.columnClues.count else { return "" }
                        return manager.columnClues[column].map(String.init).joined(separator: " ") 
                    },
                    set: { manager.updateColumnClue(column: column, string: $0) }
                ))
                    .onSubmit {
                        guard column < manager.columnClues.count else { return }
                        manager.updateColumnClue(column: column, string: manager.columnClues[column].map(String.init).joined(separator: " "))
                    }
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding()
    }
}

#Preview {
    ClueEntryView(manager: GameManager())
}
