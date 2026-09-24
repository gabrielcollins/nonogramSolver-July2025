# JSON Export

## Goal

One button, **"Export JSON"**, writes the current puzzle in the authoring
format the creator writes and the shared contract defines
(`nonogramImageCreator/docs/json-format.md`). The editor reads the same format
back, so a puzzle can go creator → editor → creator, or editor → editor,
without a conversion step, and nothing another tool recorded about it is lost.

This replaces the July "Export for iOS App" button, which wrote the game's
`PuzzleSet` directly. Puzzles reach the game through the creator's merge
instead (see [Into the game](#into-the-game)).

## Format

```json
{
  "name": "hoary_marmots_02_sitting_watch_20x20",
  "rows": 20,
  "columns": 20,
  "matrix": [
    [1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1],
    ...
  ],
  "rowClues": [[2,2],[1,7,1],...],
  "columnClues": [[2],[1,1],...],
  "metadata": {"createdBy": "Original puzzle design", "difficulty": "medium", "lineSteps": 94, "solverCheck": "UNIQUE", ...}
}
```

Keys come in contract order. Each matrix row sits on one line, and each clue
list and the metadata on one line, so the file reads like the picture; any
JSON reader treats it the same as the creator's fully expanded layout.
`rows` and `columns` come from the matrix, and both clue lists are derived
from it, exactly as tap-editing derives them.

## Metadata

The imported file's `metadata` is carried through whole: `createdBy`,
`sourceTitle`, `style`, and any key this app does not know. Metadata keys are
written in alphabetical order, because the app holds them as a dictionary.
Over that, the export sets:

| Key | Value |
| --- | --- |
| `solverCheck` | `"UNIQUE"` when the line solver completed the board itself (it took steps, never stalled, never hit a contradiction), which proves the solution is unique; otherwise `"unverified"`. Same vocabulary as the extractor's `solver_check.csv`. |
| `lineSteps` | The line solver's step count, written only when `solverCheck` is `"UNIQUE"`. |
| `difficulty` | Measured from the solve when there was one; otherwise the imported value; otherwise `medium`. |
| `createdBy` | `"nonogramSolver"`, only when the imported file named no creator. |

A new import replaces the metadata; changing the grid size clears it, because
that starts a new puzzle.

### Difficulty

`solvingStepCount` counts one step per **line** solved, so raw counts scale
with grid size — a 20x20 needs 40 steps just to look at every line once.
Dividing by `rows + columns` gives **sweeps**, which is comparable across
sizes. Under 2 sweeps is `easy`, under 3.5 is `medium`, beyond that is
`difficult` — the vocabulary the game's shipped puzzles already use. The step
count and sweep figure are shown beside the button so the thresholds can be
calibrated against real puzzles.

## Export gating

The button is disabled, with the reason shown beneath it, when:

- the puzzle has no name, or
- any row or column is blank.

Blank lines are barred because the game's clue generator emits `[0]` for one
and the solver's bulk parser rejects it, so a blank line breaks both
directions of the pipeline. Beneath the button the app also shows whether the
export will be `UNIQUE` or `unverified`: to verify, clear the board and run the
solver before exporting.

## Import

`PuzzleImportParser` accepts a bare matrix, a creator export (`matrix` key,
with its `metadata`), or a `PuzzleSet`. A set holding several puzzles opens a
picker rather than silently loading the first one, and the chosen puzzle's
name populates the name field so a round trip does not drop it.

Import deliberately does **not** reject blank lines: importing exists to load
a puzzle for repair, so that rule is enforced on export.

## Into the game

The creator merges exported files into the game's set, taking `name` and
`metadata.difficulty` from each:

```sh
PYTHONPATH=src python3 -m nonogram_image_creator.export_ios \
  exported.json --output .../Data/testing.json
```

`gridJSON` and `cluesJSON` remain on `GameManager` for the clipboard helpers
and tests, but no longer back a button.
