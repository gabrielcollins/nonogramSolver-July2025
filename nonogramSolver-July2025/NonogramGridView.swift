import SwiftUI

struct NonogramGridView: View {
    @ObservedObject var manager: GameManager

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let cellWidth = size / CGFloat(manager.grid.columns)
            let cellHeight = size / CGFloat(manager.grid.rows)
            ZStack {
                // grid
                ForEach(0..<manager.grid.rows, id: \.self) { row in
                    ForEach(0..<manager.grid.columns, id: \.self) { column in
                        Rectangle()
                            .strokeBorder(lineWidth: lineWidth(row: row, column: column))
                            .background(tileColor(manager.grid.tiles[row][column]))
                            .frame(width: cellWidth, height: cellHeight)
                            .position(x: cellWidth * (CGFloat(column) + 0.5), y: cellHeight * (CGFloat(row) + 0.5))
                            .onTapGesture { manager.tap(row: row, column: column) }
                    }
                }
            }
        }
        .aspectRatio(CGFloat(manager.grid.columns) / CGFloat(manager.grid.rows), contentMode: .fit)
    }

    func tileColor(_ state: TileState) -> some View {
        switch state {
        case .filled:
            return Color.black
        case .empty:
            return Color.white.overlay(Text("x").font(.caption))
        case .unmarked:
            return Color.white
        }
    }

    func lineWidth(row: Int, column: Int) -> CGFloat {
        if row % 5 == 0 || column % 5 == 0 {
            return 2
        }
        return 1
    }
}

#Preview {
    NonogramGridView(manager: GameManager())
}
