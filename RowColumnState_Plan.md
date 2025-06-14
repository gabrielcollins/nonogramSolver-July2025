# Plan for Row/Column Clue Persistence

## Goal
Track distinct clue entries for each selectable row and column count (5-40). When a user changes the puzzle size, previously entered clues for that size should reappear. Data persists between launches via `GameState`.

## Steps
1. **Data Model Changes**
   - Extend `GameState` to store `rowCluesBySize: [Int:[[Int]]]` and `columnCluesBySize: [Int:[[Int]]]`.
   - Remove old single `rowClues` and `columnClues` fields.
2. **GameManager**
   - Add properties mirroring the new dictionaries plus `rowClues`/`columnClues` for the currently selected size.
   - Modify initializer and `load()` to populate dictionaries and load the arrays for the saved grid size.
   - Update `save()` to persist dictionaries.
   - When `set(rows:columns:)` is called, save current clues to the appropriate dictionary keys then retrieve arrays for the new sizes (or create empty arrays).
   - Update `updateRowClue` and `updateColumnClue` to update both the current arrays and the dictionaries.
3. **UI Adjustments**
   - Display a text field for every row and column of the selected size (remove `min(5, ...)`).
   - Add `.onSubmit` to each text field so clues are saved after the user presses return.
4. **Builder & Tests**
   - Update `GameManagerBuilder` to work with the new model fields.
   - Adjust existing unit tests for the new `GameState` definition.

This plan enables independent clue sets for each grid size and ensures persistence across launches.
