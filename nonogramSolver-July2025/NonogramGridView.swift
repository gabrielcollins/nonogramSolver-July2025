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
                        // Custom border with thick outer edges
                        ZStack {
                            // Top border (thick outer edge)
                            Rectangle()
                                .fill(GridLineConfig.lineColor)
                                .frame(height: GridLineConfig.thickLineWidth)
                                .offset(y: -maxColumnClueHeight/2 + GridLineConfig.thickLineWidth/2)
                            
                            // Bottom border (thick to separate from row clues)
                            Rectangle()
                                .fill(GridLineConfig.lineColor)
                                .frame(height: GridLineConfig.thickLineWidth)
                                .offset(y: maxColumnClueHeight/2 - GridLineConfig.thickLineWidth/2)
                            
                            // Left border (thick outer edge)
                            Rectangle()
                                .fill(GridLineConfig.lineColor)
                                .frame(width: GridLineConfig.thickLineWidth)
                                .offset(x: -maxRowClueWidth/2 + GridLineConfig.thickLineWidth/2)
                            
                            // Right border (thick to separate from column clues)
                            Rectangle()
                                .fill(GridLineConfig.lineColor)
                                .frame(width: GridLineConfig.thickLineWidth)
                                .offset(x: maxRowClueWidth/2 - GridLineConfig.thickLineWidth/2)
                        }
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
                        // Custom border with different widths for each edge to match gameplay area
                        ZStack {
                            // Top border (thick outer edge)
                            Rectangle()
                                .fill(GridLineConfig.lineColor)
                                .frame(height: GridLineConfig.thickLineWidth)
                                .offset(y: -maxColumnClueHeight/2 + GridLineConfig.thickLineWidth/2)
                            
                            // Bottom border (thick to separate from gameplay area)
                            Rectangle()
                                .fill(GridLineConfig.lineColor)
                                .frame(height: GridLineConfig.thickLineWidth)
                                .offset(y: maxColumnClueHeight/2 - GridLineConfig.thickLineWidth/2)
                            
                            // Left border
                            Rectangle()
                                .fill(GridLineConfig.lineColor)
                                .frame(width: leftBorderWidth(column: column))
                                .offset(x: -cellSize/2 + leftBorderWidth(column: column)/2)
                            
                            // Right border
                            Rectangle()
                                .fill(GridLineConfig.lineColor)
                                .frame(width: rightBorderWidth(column: column))
                                .offset(x: cellSize/2 - rightBorderWidth(column: column)/2)
                        }
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
                            // Custom border with different widths for each edge to match gameplay area
                            ZStack {
                                // Top border
                                Rectangle()
                                    .fill(GridLineConfig.lineColor)
                                    .frame(height: topBorderWidth(row: row))
                                    .offset(y: -cellSize/2 + topBorderWidth(row: row)/2)
                                
                                // Bottom border
                                Rectangle()
                                    .fill(GridLineConfig.lineColor)
                                    .frame(height: bottomBorderWidth(row: row))
                                    .offset(y: cellSize/2 - bottomBorderWidth(row: row)/2)
                                
                                // Left border (thick outer edge)
                                Rectangle()
                                    .fill(GridLineConfig.lineColor)
                                    .frame(width: GridLineConfig.thickLineWidth)
                                    .offset(x: -maxRowClueWidth/2 + GridLineConfig.thickLineWidth/2)
                                
                                // Right border (thick to separate from gameplay area)
                                Rectangle()
                                    .fill(GridLineConfig.lineColor)
                                    .frame(width: GridLineConfig.thickLineWidth)
                                    .offset(x: maxRowClueWidth/2 - GridLineConfig.thickLineWidth/2)
                            }
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
                                        // Custom border with different widths for each edge
                                        ZStack {
                                            // Top border
                                            Rectangle()
                                                .fill(GridLineConfig.lineColor)
                                                .frame(height: topBorderWidth(row: row))
                                                .offset(y: -cellSize/2 + topBorderWidth(row: row)/2)
                                            
                                            // Bottom border
                                            Rectangle()
                                                .fill(GridLineConfig.lineColor)
                                                .frame(height: bottomBorderWidth(row: row))
                                                .offset(y: cellSize/2 - bottomBorderWidth(row: row)/2)
                                            
                                            // Left border
                                            Rectangle()
                                                .fill(GridLineConfig.lineColor)
                                                .frame(width: leftBorderWidth(column: column))
                                                .offset(x: -cellSize/2 + leftBorderWidth(column: column)/2)
                                            
                                            // Right border
                                            Rectangle()
                                                .fill(GridLineConfig.lineColor)
                                                .frame(width: rightBorderWidth(column: column))
                                                .offset(x: cellSize/2 - rightBorderWidth(column: column)/2)
                                        }
                                    )
                                    .onTapGesture { manager.tap(row: row, column: column) }
                            }
                        }
                    }
                }
            }
        }
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

    // Border width functions for individual cell edges
    func topBorderWidth(row: Int) -> CGFloat {
        // First row has thick top border (outer edge), thick borders also appear after every 5th row
        if row == 0 {
            return GridLineConfig.thickLineWidth
        }
        return row % 5 == 0 ? GridLineConfig.thickLineWidth : GridLineConfig.thinLineWidth
    }
    
    func bottomBorderWidth(row: Int) -> CGFloat {
        // Thick border after every 5th row (positions 4, 9, 14, etc.) and last row (outer edge)
        if (row + 1) % 5 == 0 {
            return GridLineConfig.thickLineWidth
        }
        // Check if this is the last row (outer edge)
        if row == manager.grid.rows - 1 {
            return GridLineConfig.thickLineWidth
        }
        return GridLineConfig.thinLineWidth
    }
    
    func leftBorderWidth(column: Int) -> CGFloat {
        // First column has thick left border (outer edge), thick borders also appear after every 5th column
        if column == 0 {
            return GridLineConfig.thickLineWidth
        }
        return column % 5 == 0 ? GridLineConfig.thickLineWidth : GridLineConfig.thinLineWidth
    }
    
    func rightBorderWidth(column: Int) -> CGFloat {
        // Thick border after every 5th column (positions 4, 9, 14, etc.) and last column (outer edge)
        if (column + 1) % 5 == 0 {
            return GridLineConfig.thickLineWidth
        }
        // Check if this is the last column (outer edge)
        if column == manager.grid.columns - 1 {
            return GridLineConfig.thickLineWidth
        }
        return GridLineConfig.thinLineWidth
    }
    
    func rowLineWidth(row: Int) -> CGFloat {
        // Use thick lines after every 5th row (positions 4, 9, 14, etc.)
        if (row + 1) % 5 == 0 {
            return GridLineConfig.thickLineWidth
        } else {
            return GridLineConfig.thinLineWidth
        }
    }
    
    func columnLineWidth(column: Int) -> CGFloat {
        // Use thick lines after every 5th column (positions 4, 9, 14, etc.)
        if (column + 1) % 5 == 0 {
            return GridLineConfig.thickLineWidth
        } else {
            return GridLineConfig.thinLineWidth
        }
    }
    

}

#Preview {
    NonogramGridView(manager: GameManager())
}
