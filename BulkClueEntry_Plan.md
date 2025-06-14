# Plan for Bulk Row and Column Clue Entry

## Goal
Allow users to paste all row or column clues at once using a JSON-like array format. A submission button validates the string, updates the grid size, and populates individual clue fields. Invalid input shows a warning above the entry area.

## Steps
1. **Parsing & Validation**
   - Accept text like `[[3], [1, 1], [4]]` for rows or columns.
   - Parse the string with `JSONDecoder` into `[[Int]]`.
   - Ensure the outer array length is 5–40 and divisible by 5.
   - Verify all inner arrays contain only positive integers separated by commas.
   - On failure, set an error message displayed in red.

2. **GameManager Support**
   - Add `loadRowClues(_:)` and `loadColumnClues(_:)` methods that:
     - Call `set(rows:columns:)` to match the array count.
     - Assign `rowClues`/`columnClues` and update the persistence dictionaries.
     - Persist via `save()`.

3. **UI Implementation**
   - Create a `BulkClueEntryView` hosting two `TextEditor` fields labeled "Row Clues Array" and "Column Clues Array" with "Submit Rows" and "Submit Columns" buttons.
   - Display the validation warning text above each editor when needed.
   - After successful submission, the existing clue fields in `ContentView` should reflect the loaded arrays automatically via `GameManager`.

4. **Testing**
   - Add unit tests for the parsing logic and `loadRowClues`/`loadColumnClues` methods.
   - Update UI tests to paste a sample array and verify clue fields populate correctly.

This approach aligns with the Developer Guide: the UI observes `GameManager`, which performs all state mutations and persistence. The new view introduces no independent state beyond form input and uses `@MainActor` methods to update the model.
