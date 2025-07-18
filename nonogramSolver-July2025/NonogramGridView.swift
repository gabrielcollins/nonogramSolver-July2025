import SwiftUI

struct NonogramGridView: View {
    @ObservedObject var manager: GameManager
    
    private let cellSize: CGFloat = 25
    
    // Dynamic sizing based on clue content
    private var maxColumnClueHeight: CGFloat {
        let numberHeight: CGFloat = 12
        let spacing: CGFloat = 2
        let basePadding: CGFloat = 20 // Increased for more breathing room
        
        // Ensure we only access valid column clues
        let validColumnClues = manager.columnClues.prefix(manager.grid.columns)
        let maxClueCount = validColumnClues.map { $0.count }.max() ?? 0
        return CGFloat(maxClueCount) * numberHeight + CGFloat(max(0, maxClueCount - 1)) * spacing + basePadding
    }
    
    private var maxRowClueWidth: CGFloat {
        let digitWidth: CGFloat = 6 // approximate width per digit
        let spacing: CGFloat = 4
        let basePadding: CGFloat = 24 // Increased for more breathing room
        
        // Ensure we only access valid row clues
        let validRowClues = manager.rowClues.prefix(manager.grid.rows)
        let maxWidth = validRowClues.map { clue in
            let totalCharacters = clue.map { String($0).count }.reduce(0, +)
            let spacingWidth = CGFloat(max(0, clue.count - 1)) * spacing
            return CGFloat(totalCharacters) * digitWidth + spacingWidth
        }.max() ?? 0
        
        return maxWidth + basePadding
    }

    var body: some View {
        VStack(spacing: 0) {
            ColumnCluesView(
                manager: manager,
                cellSize: cellSize,
                maxRowClueWidth: maxRowClueWidth,
                maxColumnClueHeight: maxColumnClueHeight
            )

            HStack(spacing: 0) {
                RowCluesView(
                    manager: manager,
                    cellSize: cellSize,
                    maxRowClueWidth: maxRowClueWidth
                )

                VStack(spacing: 0) {
                    ForEach(0..<manager.grid.rows, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<manager.grid.columns, id: \.self) { column in
                                GridCellView(manager: manager, row: row, column: column, cellSize: cellSize)
                            }
                        }
                        .background(
                            (row == manager.errorRow || row == manager.contradictionRow) ? Color.red.opacity(0.3) :
                            (row == manager.highlightedRow ? (manager.unsolvableByStep ? Color.orange.opacity(0.3) : Color.yellow.opacity(0.3)) : Color.clear)
                        )
                    }
                }
            }
        }
    }

    // Deprecated helpers moved to GridStyle in NonogramGridComponents.swift
}

#Preview {
    NonogramGridView(manager: GameManager())
}
