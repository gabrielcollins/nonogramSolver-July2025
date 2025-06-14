import SwiftUI

struct BulkClueEntryView: View {
    @ObservedObject var manager: GameManager
    @State private var rowText = ""
    @State private var columnText = ""
    @State private var rowError: String?
    @State private var columnError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    if let rowError = rowError {
                        Text(rowError)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    Text("Row Clues Array:")
                    TextEditor(text: $rowText)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 80)
                    Button("Submit Rows") { submitRows() }
                        .buttonStyle(.borderedProminent)
                }
                VStack(alignment: .leading, spacing: 4) {
                    if let columnError = columnError {
                        Text(columnError)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    Text("Column Clues Array:")
                    TextEditor(text: $columnText)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 80)
                    Button("Submit Columns") { submitColumns() }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .navigationTitle("Bulk Entry")
    }

    private func submitRows() {
        switch BulkClueParser.parse(rowText) {
        case .success(let clues):
            manager.loadRowClues(clues)
            rowError = nil
        case .failure(let error):
            rowError = "Failed: \(error.errorDescription ?? "Unknown error")"
        }
    }

    private func submitColumns() {
        switch BulkClueParser.parse(columnText) {
        case .success(let clues):
            manager.loadColumnClues(clues)
            columnError = nil
        case .failure(let error):
            columnError = "Failed: \(error.errorDescription ?? "Unknown error")"
        }
    }
}

#Preview {
    BulkClueEntryView(manager: GameManager())
}
