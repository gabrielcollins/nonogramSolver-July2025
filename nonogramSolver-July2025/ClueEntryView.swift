import SwiftUI

struct ClueEntryView: View {
    @ObservedObject var manager: GameManager

    var body: some View {
        VStack(alignment: .leading) {
            Text("Row Clues")
            ForEach(0..<manager.grid.rows, id: \.self) { row in
                TextField("Row \(row)", text: Binding(
                    get: { manager.rowClues[row].map(String.init).joined(separator: " ") },
                    set: { manager.updateRowClue(row: row, string: $0) }
                ))
                    .textFieldStyle(.roundedBorder)
            }
            Text("Column Clues")
            ForEach(0..<manager.grid.columns, id: \.self) { column in
                TextField("Col \(column)", text: Binding(
                    get: { manager.columnClues[column].map(String.init).joined(separator: " ") },
                    set: { manager.updateColumnClue(column: column, string: $0) }
                ))
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding()
    }
}

#Preview {
    ClueEntryView(manager: GameManager())
}
