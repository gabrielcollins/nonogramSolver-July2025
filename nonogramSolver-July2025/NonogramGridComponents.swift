import SwiftUI

struct GridStyle {
    static let thickLineWidth: CGFloat = 2.0
    static let thinLineWidth: CGFloat = 0.5
    static let lineColor: Color = .black
    static let clueBackgroundColor: Color = .white

    static func topBorderWidth(row: Int) -> CGFloat {
        if row == 0 { return thickLineWidth }
        return row % 5 == 0 ? thickLineWidth : thinLineWidth
    }

    static func bottomBorderWidth(row: Int, totalRows: Int) -> CGFloat {
        if row == totalRows - 1 { return thickLineWidth }
        if (row + 1) % 5 == 0 { return thickLineWidth }
        return thinLineWidth
    }

    static func leftBorderWidth(column: Int) -> CGFloat {
        if column == 0 { return thickLineWidth }
        return column % 5 == 0 ? thickLineWidth : thinLineWidth
    }

    static func rightBorderWidth(column: Int, totalColumns: Int) -> CGFloat {
        if column == totalColumns - 1 { return thickLineWidth }
        if (column + 1) % 5 == 0 { return thickLineWidth }
        return thinLineWidth
    }
}

extension TileState {
    var view: some View {
        switch self {
        case .filled:
            return AnyView(Color.black)
        case .empty:
            return AnyView(Color.white.overlay(Text("×").font(.caption2).foregroundColor(.gray)))
        case .unmarked:
            return AnyView(Color.white)
        }
    }
}

struct GridCellView: View {
    @ObservedObject var manager: GameManager
    let row: Int
    let column: Int
    let cellSize: CGFloat

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .background(
                (row < manager.grid.rows && column < manager.grid.columns && 
                 row < manager.grid.tiles.count && column < manager.grid.tiles[row].count) 
                ? manager.grid.tiles[row][column].view 
                : TileState.unmarked.view
            )
            .frame(width: cellSize, height: cellSize)
            .overlay(
                ZStack {
                    Rectangle()
                        .fill(GridStyle.lineColor)
                        .frame(height: GridStyle.topBorderWidth(row: row))
                        .offset(y: -cellSize/2 + GridStyle.topBorderWidth(row: row)/2)
                    Rectangle()
                        .fill(GridStyle.lineColor)
                        .frame(height: GridStyle.bottomBorderWidth(row: row, totalRows: manager.grid.rows))
                        .offset(y: cellSize/2 - GridStyle.bottomBorderWidth(row: row, totalRows: manager.grid.rows)/2)
                    Rectangle()
                        .fill(GridStyle.lineColor)
                        .frame(width: GridStyle.leftBorderWidth(column: column))
                        .offset(x: -cellSize/2 + GridStyle.leftBorderWidth(column: column)/2)
                    Rectangle()
                        .fill(GridStyle.lineColor)
                        .frame(width: GridStyle.rightBorderWidth(column: column, totalColumns: manager.grid.columns))
                        .offset(x: cellSize/2 - GridStyle.rightBorderWidth(column: column, totalColumns: manager.grid.columns)/2)
                }
            )
            .onTapGesture { manager.tap(row: row, column: column) }
    }
}

struct ColumnCluesView: View {
    @ObservedObject var manager: GameManager
    let cellSize: CGFloat
    let maxRowClueWidth: CGFloat
    let maxColumnClueHeight: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(GridStyle.clueBackgroundColor)
                .frame(width: maxRowClueWidth, height: maxColumnClueHeight)
                .overlay(
                    ZStack {
                        Rectangle()
                            .fill(GridStyle.lineColor)
                            .frame(height: GridStyle.thickLineWidth)
                            .offset(y: -maxColumnClueHeight/2 + GridStyle.thickLineWidth/2)
                        Rectangle()
                            .fill(GridStyle.lineColor)
                            .frame(height: GridStyle.thickLineWidth)
                            .offset(y: maxColumnClueHeight/2 - GridStyle.thickLineWidth/2)
                        Rectangle()
                            .fill(GridStyle.lineColor)
                            .frame(width: GridStyle.thickLineWidth)
                            .offset(x: -maxRowClueWidth/2 + GridStyle.thickLineWidth/2)
                        Rectangle()
                            .fill(GridStyle.lineColor)
                            .frame(width: GridStyle.thickLineWidth)
                            .offset(x: maxRowClueWidth/2 - GridStyle.thickLineWidth/2)
                    }
                )
            ForEach(0..<manager.grid.columns, id: \.self) { column in
                VStack(spacing: 2) {
                    Spacer()
                    ForEach(Array((column < manager.columnClues.count ? manager.columnClues[column] : []).reversed().enumerated()), id: \.offset) { index, clue in
                        Text("\(clue)")
                            .font(.footnote.bold())
                            .foregroundColor(.black)
                    }
                    Spacer().frame(maxHeight: 8)
                }
                .frame(width: cellSize, height: maxColumnClueHeight)
                .background(GridStyle.clueBackgroundColor)
                .overlay(
                    ZStack {
                        Rectangle()
                            .fill(GridStyle.lineColor)
                            .frame(height: GridStyle.thickLineWidth)
                            .offset(y: -maxColumnClueHeight/2 + GridStyle.thickLineWidth/2)
                        Rectangle()
                            .fill(GridStyle.lineColor)
                            .frame(height: GridStyle.thickLineWidth)
                            .offset(y: maxColumnClueHeight/2 - GridStyle.thickLineWidth/2)
                        Rectangle()
                            .fill(GridStyle.lineColor)
                            .frame(width: GridStyle.leftBorderWidth(column: column))
                            .offset(x: -cellSize/2 + GridStyle.leftBorderWidth(column: column)/2)
                        Rectangle()
                            .fill(GridStyle.lineColor)
                            .frame(width: GridStyle.rightBorderWidth(column: column, totalColumns: manager.grid.columns))
                            .offset(x: cellSize/2 - GridStyle.rightBorderWidth(column: column, totalColumns: manager.grid.columns)/2)
                    }
                )
            }
        }
    }
}

struct RowCluesView: View {
    @ObservedObject var manager: GameManager
    let cellSize: CGFloat
    let maxRowClueWidth: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<manager.grid.rows, id: \.self) { row in
                HStack(spacing: 2) {
                    Spacer().frame(maxWidth: 8)
                    ForEach(Array((row < manager.rowClues.count ? manager.rowClues[row] : []).enumerated()), id: \.offset) { index, clue in
                        Text("\(clue)")
                            .font(.footnote.bold())
                            .foregroundColor(.black)
                    }
                    Spacer().frame(maxWidth: 8)
                }
                .frame(width: maxRowClueWidth, height: cellSize)
                .background(row == manager.highlightedRow ? Color.yellow.opacity(0.3) : GridStyle.clueBackgroundColor)
                .overlay(
                    ZStack {
                        Rectangle()
                            .fill(GridStyle.lineColor)
                            .frame(height: GridStyle.topBorderWidth(row: row))
                            .offset(y: -cellSize/2 + GridStyle.topBorderWidth(row: row)/2)
                        Rectangle()
                            .fill(GridStyle.lineColor)
                            .frame(height: GridStyle.bottomBorderWidth(row: row, totalRows: manager.grid.rows))
                            .offset(y: cellSize/2 - GridStyle.bottomBorderWidth(row: row, totalRows: manager.grid.rows)/2)
                        Rectangle()
                            .fill(GridStyle.lineColor)
                            .frame(width: GridStyle.thickLineWidth)
                            .offset(x: -maxRowClueWidth/2 + GridStyle.thickLineWidth/2)
                        Rectangle()
                            .fill(GridStyle.lineColor)
                            .frame(width: GridStyle.thickLineWidth)
                            .offset(x: maxRowClueWidth/2 - GridStyle.thickLineWidth/2)
                    }
                )
            }
        }
    }
}
