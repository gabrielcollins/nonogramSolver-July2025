# Dynamic Clue State Persistence Plan

This plan outlines the changes required to allow row and column clues to be
stored separately for each grid size. When the user picks a new size from the
pickers, previously entered clues should reappear. Each clue entry should be
committed when the user presses **Return** in the corresponding text field.

## 1. Model Updates
- Introduce `GameStateCollection` – a `Codable` wrapper around a dictionary
  `[String: GameState]`. The key is `"{rows}x{columns}"`.
- Extend `GameStateStoring` to save and load this collection instead of a single
  `GameState`.

## 2. Persistence
- Update `GameStateStore` so `save` writes the entire collection and `load`
  returns a collection (empty by default if no file exists).

## 3. GameManager
- Hold a `GameStateCollection` property called `states`.
- Provide a helper `currentKey` computed from `grid.rows` and `grid.columns`.
- `load()` populates `states` from the store and sets `grid`, `rowClues` and
  `columnClues` from the entry matching `currentKey` or creates a new empty one.
- `save()` updates `states[currentKey]` with the current grid and clues then
  persists the whole collection.
- `set(rows:columns:)` saves the current state before switching. It then loads
  the state for the new key or creates blank clues and grid.
- `updateRowClue`, `updateColumnClue` and `tap` update the current state and
  trigger `save()`.

## 4. ContentView
- Replace the fixed five clue text fields with dynamic lists that show one field
  per row or column using `ForEach(0..<manager.grid.rows)` and
  `ForEach(0..<manager.grid.columns)`.
- Use `@State` arrays `rowInputs` and `columnInputs` to hold the text for each
  field. Initialize these arrays when the grid size changes.
- Each `TextField` updates its corresponding entry in the `rowInputs` /
  `columnInputs` arrays. When the user submits the field, call
  `manager.updateRowClue` or `manager.updateColumnClue` with the current text.

## 5. Tests
- Adapt `GameStateStore` tests to work with the new collection based
  persistence. The existing behaviour (tapping a cell, saving, loading and
  comparing) remains the same but now uses the collection API.

