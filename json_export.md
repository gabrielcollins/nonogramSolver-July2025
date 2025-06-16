# Plan for JSON Export of Puzzle State

## Goal
Provide a simple way to copy the current puzzle grid as JSON. A green "Export Grid to JSON" button is always enabled. Pressing it copies an array of arrays using `1` for `.filled` and `0` for `.empty` or `.unmarked` tiles to the macOS clipboard.

## Steps
1. **Model Helper**
   - Extend `GameManager` with a computed property `gridJSON`.
   - Convert `grid.tiles` to `[[Int]]` where `.filled` -> `1`, others -> `0`.
   - Encode with `JSONEncoder` using `.prettyPrinted` formatting and return the string.

2. **UI Layout**
   - Add an "Export Grid to JSON" button beside the puzzle grid.
   - The button is always green and enabled regardless of puzzle state.
   - Keep the existing controls and clue entry sections below the grid as described in the Developer Guide.

3. **Styling**
   - Give the button a fixed width (~250pt) so it aligns with the grid.

4. **Testing**
   - Run existing unit tests to ensure no regressions.
   - Manually verify that after solving a sample puzzle, clicking the button copies the expected JSON to the clipboard.

This approach follows the Developer Guide's model‑driven architecture: `ContentView` observes `GameManager` and simply presents the new data without owning additional state.
