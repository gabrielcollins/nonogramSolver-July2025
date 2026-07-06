import SwiftUI
import UniformTypeIdentifiers

/// Minimal document wrapper so exports go through the standard save panel.
struct PuzzleJSONDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = text
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

struct ContentView: View {
    @StateObject private var manager: GameManager
    @State private var bulkRowText = ""
    @State private var bulkColumnText = ""
    @State private var bulkRowError: String?
    @State private var bulkColumnError: String?
    @State private var showingPuzzleImporter = false
    @State private var importError: String?
    @State private var importDropTargeted = false
    @State private var showingExporter = false
    @State private var exportDocument: PuzzleJSONDocument?

    init(manager: GameManager) {
        _manager = StateObject(wrappedValue: manager)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    HStack(alignment: .top, spacing: 20) {
                        NonogramGridView(manager: manager)

                        Button("Export Grid to JSON") {
                            exportDocument = PuzzleJSONDocument(text: manager.gridJSON)
                            showingExporter = true
                        }
                        .frame(width: 250)
                        .buttonStyle(.borderedProminent)
                        .tint(.green)

                        Button("Export Clues to JSON") {
                            exportDocument = PuzzleJSONDocument(text: manager.cluesJSON)
                            showingExporter = true
                        }
                        .frame(width: 250)
                        .buttonStyle(.borderedProminent)
                        .tint(manager.hasCompleteClues ? .green : .gray)
                        .disabled(!manager.hasCompleteClues)
                        .fileExporter(
                            isPresented: $showingExporter,
                            document: exportDocument,
                            contentType: .json,
                            defaultFilename: "\(manager.grid.rows)-\(manager.grid.columns)-"
                        ) { _ in
                            exportDocument = nil
                        }

                        VStack(spacing: 8) {
                            Button("Import Puzzle JSON…") {
                                showingPuzzleImporter = true
                            }
                            .frame(width: 250)
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                            .fileImporter(
                                isPresented: $showingPuzzleImporter,
                                allowedContentTypes: [.json, .plainText]
                            ) { result in
                                importPuzzle(from: result)
                            }

                            VStack(spacing: 4) {
                                Image(systemName: "arrow.down.doc")
                                    .font(.title3)
                                Text("or drop a JSON file here")
                                    .font(.caption)
                            }
                            .foregroundColor(importDropTargeted ? .blue : .secondary)
                            .frame(width: 250, height: 64)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(
                                        importDropTargeted ? Color.blue : Color.secondary.opacity(0.5),
                                        style: StrokeStyle(lineWidth: 1.5, dash: [6])
                                    )
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(importDropTargeted ? Color.blue.opacity(0.1) : Color.clear)
                                    )
                            )
                            .dropDestination(for: URL.self) { urls, _ in
                                guard let url = urls.first else { return false }
                                importPuzzle(url: url)
                                return true
                            } isTargeted: { targeted in
                                importDropTargeted = targeted
                            }

                            if let importError = importError {
                                Text(importError)
                                    .foregroundColor(.red)
                                    .font(.caption)
                                    .frame(width: 250)
                            }
                        }
                    }

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
                                    Task { await manager.autoSolve() }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(manager.contradictionEncountered ? .red : (manager.unsolvableByStep ? .yellow : (manager.isPuzzleSolved ? .green : nil)))
                                .disabled(manager.isPuzzleSolved)

                                Button("Step Solve") {
                                    manager.stepSolve()
                                }
                                .buttonStyle(.bordered)
                                .tint(manager.contradictionEncountered ? .red : (manager.unsolvableByStep ? .yellow : (manager.isPuzzleSolved ? .green : nil)))
                                .disabled(manager.isPuzzleSolved)

                                Button("Clear") {
                                    manager.clearBoard()
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        if manager.contradictionEncountered {
                            Text("Contradiction encountered!")
                                .font(.caption)
                                .foregroundColor(.red)
                        } else if manager.unsolvableByStep {
                            Text("Beyond Simple Level")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        } else {
                            Text(manager.isPuzzleSolved ? "Solved in \(manager.solvingStepCount) steps" : "Solving Steps: \(manager.solvingStepCount)")
                                .font(.caption)
                                .foregroundColor(manager.isPuzzleSolved ? .green : .primary)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                    
                    // Clue input section
                    VStack(spacing: 10) {
                        Text("Clue Input")
                            .font(.headline)
                        
                        HStack {
                            VStack(alignment: .leading) {
                                HStack {
                                    Text("Row Clues:")
                                        .font(.subheadline)
                                    Spacer()
                                    Button("Clear Rows") {
                                        manager.clearRowClues()
                                    }
                                    .font(.caption)
                                    .buttonStyle(.bordered)
                                }
                                if let bulkRowError = bulkRowError {
                                    Text(bulkRowError)
                                        .foregroundColor(.red)
                                        .font(.caption)
                                }
                                TextEditor(text: $bulkRowText)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(height: 60)
                                Button("Load Rows") { submitBulkRows() }
                                    .buttonStyle(.borderedProminent)
                                ForEach(0..<manager.grid.rows, id: \.self) { row in
                                    HStack {
                                        Text("R\(row+1):")
                                            .frame(width: 30, alignment: .leading)
                                        TextField("e.g. 2 1", text: Binding(
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
                                }
                            }

                            VStack(alignment: .leading) {
                                HStack {
                                    Text("Column Clues:")
                                        .font(.subheadline)
                                    Spacer()
                                    Button("Clear Columns") {
                                        manager.clearColumnClues()
                                    }
                                    .font(.caption)
                                    .buttonStyle(.bordered)
                                }
                                if let bulkColumnError = bulkColumnError {
                                    Text(bulkColumnError)
                                        .foregroundColor(.red)
                                        .font(.caption)
                                }
                                TextEditor(text: $bulkColumnText)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(height: 60)
                                Button("Load Columns") { submitBulkColumns() }
                                    .buttonStyle(.borderedProminent)
                                ForEach(0..<manager.grid.columns, id: \.self) { column in
                                    HStack {
                                        Text("C\(column+1):")
                                            .frame(width: 30, alignment: .leading)
                                        TextField("e.g. 1 3", text: Binding(
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
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding()
            }
            .navigationTitle("Nonogram Solver")
        }
    }

    private func importPuzzle(from result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            importPuzzle(url: url)
        case .failure:
            importError = nil
        }
    }

    private func importPuzzle(url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            importError = "Failed: could not read file"
            return
        }
        switch PuzzleImportParser.parse(data) {
        case .success(let matrix):
            manager.importGrid(matrix: matrix)
            importError = nil
        case .failure(let error):
            importError = "Failed: \(error.errorDescription ?? "Unknown error")"
        }
    }

    private func submitBulkRows() {
        switch BulkClueParser.parse(bulkRowText) {
        case .success(let clues):
            manager.loadRowClues(clues)
            bulkRowError = nil
        case .failure(let error):
            bulkRowError = "Failed: \(error.errorDescription ?? "Unknown error")"
        }
    }

    private func submitBulkColumns() {
        switch BulkClueParser.parse(bulkColumnText) {
        case .success(let clues):
            manager.loadColumnClues(clues)
            bulkColumnError = nil
        case .failure(let error):
            bulkColumnError = "Failed: \(error.errorDescription ?? "Unknown error")"
        }
    }
}

#Preview {
    ContentView(manager: GameManager())
}
