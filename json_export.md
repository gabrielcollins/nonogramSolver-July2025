# Plan for JSON Export of Solved Puzzle

## Goal
Provide a simple way to copy the solved puzzle as JSON. When the board has no `.unmarked` tiles (`isPuzzleSolved` from the Developer Guide) a green "Export Solution to JSON" button becomes enabled. Pressing it copies an array of arrays using `1` for `.filled` and `0` for other tiles to the macOS clipboard.

## Steps
1. **Model Helper**
   - Extend `GameManager` with a computed property `solvedGridJSON`.
   - Convert `grid.tiles` to `[[Int]]` where `.filled` -> `1`, others -> `0`.
   - Encode with `JSONEncoder` using `.prettyPrinted` formatting and return the string.

2. **UI Layout**
   - Add an "Export Solution to JSON" button beside the puzzle grid.
   - The button is disabled and gray until `manager.isPuzzleSolved` becomes `true`, after which it turns green.
   - Keep the existing controls and clue entry sections below the grid as described in the Developer Guide.

3. **Styling**
   - Give the button a fixed width (~250pt) so it aligns with the grid.

4. **Testing**
   - Run existing unit tests to ensure no regressions.
   - Manually verify that after solving a sample puzzle, clicking the button copies the expected JSON to the clipboard.

This approach follows the Developer Guide's model‑driven architecture: `ContentView` observes `GameManager` and simply presents the new data without owning additional state.
