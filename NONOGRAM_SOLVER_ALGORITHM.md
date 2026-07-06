# Current Nonogram Solver Algorithm

This app currently uses a line-level brute-force solver. It does not brute-force the
entire board. Instead, it repeatedly solves one row or one column by enumerating
every legal way that line could satisfy its clues, then filling only the squares
that are identical across all legal possibilities.

## State Model

Each cell in the grid is one of three states:

- `unmarked`: unknown
- `filled`: part of the final picture
- `empty`: known blank space

The app stores row clues and column clues separately. A clue list such as
`[3, 1]` means the line must contain a run of three filled cells, at least one
empty cell, then a run of one filled cell.

## Step Solver

`stepSolve()` performs one deduction step at a time.

1. Stop immediately if the puzzle is already solved, a contradiction has already
   been found, or the app has marked the puzzle as not solvable by this step
   method.
2. Work through rows first, then columns.
3. Rows are scanned from bottom to top. Columns are scanned from left to right.
4. Solved lines are skipped. A line is considered solved when it has no
   `unmarked` cells left.
5. If the selected row or column has no clues entered, the app highlights that
   line as a clue-entry error instead of solving.
6. Otherwise, the app calls the row or column solver for that line.

`autoSolve()` simply calls `stepSolve()` repeatedly with a short delay between
steps until the puzzle is solved, a contradiction is found, or the solver decides
it cannot make further progress.

## Line Permutation Generation

For a single row or column, the solver calls `generateLinePermutations`.

That function recursively places each clue block into the line in every possible
legal position:

1. Cells before a placed block are treated as `empty`.
2. Cells inside the placed block are treated as `filled`.
3. A required `empty` separator is inserted between clue blocks.
4. Placements are rejected when they conflict with the current board state.
   For example, a block cannot cover a cell already marked `empty`, and the
   solver cannot turn an already `filled` cell into `empty`.
5. Placements are pruned when the remaining clue blocks can no longer fit in the
   remaining line length.
6. After generation, candidates are filtered again to ensure every known
   non-`unmarked` cell from the current board is preserved.

The result is the complete set of line-level solutions that match the clue list
and remain compatible with the current board state.

## Consensus Deduction

After all valid permutations for a line are generated, the solver compares each
cell position across every permutation:

- If every valid permutation has the same state at that position, the grid is
  updated to that state.
- If valid permutations disagree at that position, the cell remains unchanged.

This is the main deduction rule. The solver only writes information that is
forced by every currently possible version of that row or column.

## Contradictions

If a row or column has zero valid permutations, the app marks a contradiction:

- `contradictionRow` is set when a row cannot satisfy its clues.
- `contradictionColumn` is set when a column cannot satisfy its clues.
- `contradictionEncountered` stops further solving.

This means the current board state and clue set are inconsistent for at least one
line.

## No-Progress Detection

The app also tracks whether a solving step changed any cells. If it cycles back
to a previously considered line without making progress, it sets
`unsolvableByStep`.

This does not prove the puzzle is mathematically unsolvable. It means the puzzle
cannot currently be completed by this solver's repeated line-consensus method.

## What This Solver Can Establish

This solver can:

- Fill cells that are forced by all valid permutations of a single row or column.
- Propagate those forced cells between rows and columns over repeated steps.
- Detect direct row or column contradictions.
- Solve puzzles that can be completed by repeated line-level consensus.

## What This Solver Does Not Establish

This solver does not currently:

- Search the full board with guessing or backtracking.
- Prove that a clue set has exactly one solution.
- Prove that an incomplete puzzle is globally unsolvable.
- Use advanced multi-line inference beyond row/column propagation.
- Use SAT, exact cover, integer programming, or other global constraint methods.
- Rank puzzle difficulty using human-solving techniques.

## Research Classification

For comparison against other nonogram methods, this app is best described as:

> Exhaustive line permutation generation plus consensus propagation.

It is brute force at the row-or-column level, not at the whole-board level. This
makes it useful as a simple validator and baseline solver, but it is incomplete
compared with solvers that add recursive search, uniqueness checks, SAT/ILP
encoding, exact-cover methods, or richer human-style deduction rules.
