# Puzzle Catalog

The catalog of record for accepted puzzles, exported from the solver/editor
at the end of the authoring workflow (see `nonogramImageCreator/GAME_PLAN.md`
and the shared contract in `nonogramImageCreator/docs/json-format.md`).

Each accepted puzzle is stored as JSON conforming to the shared contract:
matrix (0/1), row clues, column clues, and metadata. Requirements:

- Rows and columns are each a multiple of 5, between 5 and 40.
- No empty rows or columns.
- The puzzle was fully solved by the line solver (which proves the solution
  is unique) and human test-solved before export.
- Metadata records the solving step count (crude difficulty rating).

Naming convention: `<name>_<rows>x<columns>.json` (e.g. `marmot_20x25.json`).
