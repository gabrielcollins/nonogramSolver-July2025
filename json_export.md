# JSON Export

## Goal

One button, **"Export for iOS App"**, writes the current puzzle in the format
the shipping game reads. Everything downstream of the editor speaks that one
format, so a puzzle can go editor → game, or game → editor → game, without a
conversion step in between.

This replaces the earlier pair of buttons ("Export Grid to JSON" and "Export
Clues to JSON"), which emitted two files in two shapes that neither the game
nor the creator read directly.

## Format

An iOS game `PuzzleSet` holding one puzzle (see
`nonogramImageCreator/docs/json-format.md` for the full contract):

```json
{
  "setName": "Testing",
  "puzzles": [
    {
      "id": "testing_new_mouse",
      "name": "New Mouse",
      "difficulty": "medium",
      "solution": [[0, 1, 1]]
    }
  ]
}
```

Clues are deliberately **not** written. `PuzzleService.generateClues(from:)`
in the game derives both clue sets from `solution` at load time, so stored
clues would be data that could silently drift out of agreement with the grid.

Each export is a single-puzzle set. Merging several into the one set file the
game loads is the creator's job:

```sh
PYTHONPATH=src python3 -m nonogram_image_creator.export_ios \
  exported.json --output .../Data/testing.json
```

That merge inherits the name, id, and difficulty from this export, so nothing
has to be retyped.

## Name and difficulty

The solver has no other notion of puzzle identity, so a **name field** sits
beside the button. It supplies `name`, and `id` is its slug prefixed by the
set (`New Mouse` → `testing_new_mouse`).

`difficulty` is derived from the line solver, which is already the workflow's
acceptance gate:

- `solvingStepCount` counts one step per **line** solved, so raw counts scale
  with grid size — a 20x20 needs 40 steps just to look at every line once.
- Dividing by `rows + columns` gives **sweeps**, which is comparable across
  sizes.
- Under 2 sweeps is `easy`, under 3.5 is `medium`, beyond that is
  `difficult`.

The vocabulary matches the puzzles already shipping in the game (`medium`,
`difficult`), rather than adding `hard` as a synonym. The game only checks
that the string is non-empty, so this is a consistency choice.

An unsolved board has nothing to measure and falls back to `medium`, labelled
"unverified" in the UI. The raw step count and sweep figure are shown next to
the button so the thresholds can be calibrated against real puzzles instead of
trusted blindly.

## Export gating

The button is disabled, with the reason shown beneath it, when:

- the puzzle has no name, or
- any row or column is blank.

Blank lines are barred because the game's clue generator emits `[0]` for one
and the solver's bulk parser rejects it — so a blank line breaks both
directions of the pipeline.

## Import

`PuzzleImportParser` accepts a bare matrix, a creator export (`matrix` key),
or a `PuzzleSet` — so the app reads back exactly what it writes. A set holding
several puzzles opens a picker rather than silently loading the first one, and
the chosen puzzle's name populates the name field so a round trip does not
drop it.

Import deliberately does **not** reject blank lines: importing exists to load
a puzzle for repair, so that rule is enforced on export, where it gates
shipping.

`gridJSON` and `cluesJSON` remain on `GameManager` — they are still used by
the clipboard helpers and by tests — but no longer back a button.
