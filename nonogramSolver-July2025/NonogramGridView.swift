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
    private let clueWidth: CGFloat = 60
    private let clueHeight: CGFloat = 40

    var body: some View {
        VStack(spacing: 0) {
            // Column clues positioned above grid boundaries
            HStack(spacing: 0) {
                // Empty corner space
                Rectangle()
                    .fill(GridLineConfig.clueBackgroundColor)
                    .frame(width: clueWidth, height: clueHeight)
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
                                .font(.caption)
                                .foregroundColor(.black)
                        }
                    }
                    .frame(width: cellSize, height: clueHeight)
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
                            ForEach(manager.rowClues[row], id: \.self) { clue in
                                Text("\(clue)")
                                    .font(.caption)
                                    .foregroundColor(.black)
                            }
                        }
                        .frame(width: clueWidth, height: cellSize)
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
