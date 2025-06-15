# Plan for JSON Export of Solved Puzzle

## Goal
Add a view showing the solved puzzle as JSON so users can copy the result. When the board has no `.unmarked` tiles (`isPuzzleSolved` from the Developer Guide) a read‑only text region appears to the right of the puzzle grid. The JSON is an array of arrays with `1` for `.filled` and `0` for other tiles.

## Steps
1. **Model Helper**
   - Extend `GameManager` with a computed property `solvedGridJSON`.
   - Convert `grid.tiles` to `[[Int]]` where `.filled` -> `1`, others -> `0`.
   - Encode with `JSONEncoder` using `.prettyPrinted` formatting and return the string.

2. **UI Layout**
   - Update `ContentView` so `NonogramGridView` and the export text appear in an `HStack`.
   - When `manager.isPuzzleSolved` is `true`, display a `ScrollView` containing the JSON string using a monospaced font and `.textSelection(.enabled)`.
   - Keep the existing controls and clue entry sections below the grid as described in the Developer Guide.

3. **Styling**
   - Limit the export area's width (~250pt) and give it a light background with padding.
   - The text window should not be editable but allow copying.

4. **Testing**
   - Run existing unit tests to ensure no regressions.
   - Manually verify that after solving a sample puzzle, the JSON appears and matches the expected format.

This approach follows the Developer Guide's model‑driven architecture: `ContentView` observes `GameManager` and simply presents the new data without owning additional state.
