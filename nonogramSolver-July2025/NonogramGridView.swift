import SwiftUI

struct NonogramGridView: View {
    @ObservedObject var manager: GameManager
    
    // Centralized gridline configuration
    struct GridLineConfig {
        static let thickLineWidth: CGFloat = 2.0
        static let thinLineWidth: CGFloat = 0.5
        static let lineColor: Color = .black
        static let clueBackgroundColor: Color = .white
    }
    
    private let cellSize: CGFloat = 25
    
    // Dynamic sizing based on clue content
    private var maxColumnClueHeight: CGFloat {
        let numberHeight: CGFloat = 12
        let spacing: CGFloat = 2
        let basePadding: CGFloat = 20 // Increased for more breathing room
        
        let maxClueCount = manager.columnClues.map { $0.count }.max() ?? 0
        return CGFloat(maxClueCount) * numberHeight + CGFloat(max(0, maxClueCount - 1)) * spacing + basePadding
    }
    
    private var maxRowClueWidth: CGFloat {
        let digitWidth: CGFloat = 6 // approximate width per digit
        let spacing: CGFloat = 4
        let basePadding: CGFloat = 24 // Increased for more breathing room
        
        let maxWidth = manager.rowClues.map { clue in
            let totalCharacters = clue.map { String($0).count }.reduce(0, +)
            let spacingWidth = CGFloat(max(0, clue.count - 1)) * spacing
            return CGFloat(totalCharacters) * digitWidth + spacingWidth
        }.max() ?? 0
        
        return maxWidth + basePadding
    }

    var body: some View {
        VStack(spacing: 0) {
            // Column clues positioned above grid boundaries
            HStack(spacing: 0) {
                // Empty corner space
                Rectangle()
                    .fill(GridLineConfig.clueBackgroundColor)
                    .frame(width: maxRowClueWidth, height: maxColumnClueHeight)
                    .overlay(
                        Rectangle()
                            .stroke(GridLineConfig.lineColor, lineWidth: GridLineConfig.thinLineWidth)
                    )
                
                // Column clue numbers positioned above their columns
                ForEach(0..<manager.grid.columns, id: \.self) { column in
                    VStack(spacing: 2) {
                        Spacer()
                        ForEach(manager.columnClues[column].reversed(), id: \.self) { clue in
                            Text("\(clue)")
                                .font(.footnote.bold())
                                .foregroundColor(.black)
                        }
                        Spacer()
                            .frame(maxHeight: 8) // Bottom padding from edge
                    }
                    .frame(width: cellSize, height: maxColumnClueHeight)
                    .background(GridLineConfig.clueBackgroundColor)
                    .overlay(
                        Rectangle()
                            .stroke(GridLineConfig.lineColor, lineWidth: columnLineWidth(column: column))
                    )
                }
            }
            
            // Grid with row clues positioned to the right of row boundaries
            HStack(spacing: 0) {
                // Row clues positioned to the right of their rows
                VStack(spacing: 0) {
                    ForEach(0..<manager.grid.rows, id: \.self) { row in
                        HStack(spacing: 2) {
                            Spacer()
                                .frame(maxWidth: 8) // Left padding to match column top padding
                            ForEach(manager.rowClues[row], id: \.self) { clue in
                                Text("\(clue)")
                                    .font(.footnote.bold())
                                    .foregroundColor(.black)
                            }
                            Spacer()
                                .frame(maxWidth: 8) // Right padding from edge
                        }
                        .frame(width: maxRowClueWidth, height: cellSize)
                        .background(GridLineConfig.clueBackgroundColor)
                        .overlay(
                            Rectangle()
                                .stroke(GridLineConfig.lineColor, lineWidth: rowLineWidth(row: row))
                        )
                    }
                }
                
                // Main grid with proper gridlines
                VStack(spacing: 0) {
                    ForEach(0..<manager.grid.rows, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<manager.grid.columns, id: \.self) { column in
                                Rectangle()
                                    .fill(Color.clear)
                                    .background(tileColor(manager.grid.tiles[row][column]))
                                    .frame(width: cellSize, height: cellSize)
                                    .overlay(
                                        Rectangle()
                                            .stroke(GridLineConfig.lineColor, lineWidth: gridLineWidth(row: row, column: column))
                                    )
                                    .onTapGesture { manager.tap(row: row, column: column) }
                            }
                        }
                    }
                }
            }
        }
        .overlay(
            // Outer border for the entire nonogram
            Rectangle()
                .stroke(GridLineConfig.lineColor, lineWidth: GridLineConfig.thickLineWidth)
        )
    }

    func tileColor(_ state: TileState) -> AnyView {
        switch state {
        case .filled:
            return AnyView(Color.black)
        case .empty:
            return AnyView(Color.white.overlay(Text("×").font(.caption2).foregroundColor(.gray)))
        case .unmarked:
            return AnyView(Color.white)
        }
    }

    func gridLineWidth(row: Int, column: Int) -> CGFloat {
        let isThickRow = row % 5 == 0
        let isThickColumn = column % 5 == 0
        
        if isThickRow || isThickColumn {
            return GridLineConfig.thickLineWidth
        } else {
            return GridLineConfig.thinLineWidth
        }
    }
    
    func rowLineWidth(row: Int) -> CGFloat {
        if row % 5 == 0 {
            return GridLineConfig.thickLineWidth
        } else {
            return GridLineConfig.thinLineWidth
        }
    }
    
    func columnLineWidth(column: Int) -> CGFloat {
        if column % 5 == 0 {
            return GridLineConfig.thickLineWidth
        } else {
            return GridLineConfig.thinLineWidth
        }
    }
    
    // Legacy function for compatibility
    func lineWidth(row: Int, column: Int) -> CGFloat {
        return gridLineWidth(row: row, column: column)
    }
}

#Preview {
    NonogramGridView(manager: GameManager())
}
