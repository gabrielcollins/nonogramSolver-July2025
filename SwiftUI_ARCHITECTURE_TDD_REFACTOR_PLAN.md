# SwiftUI Architecture TDD Refactor Plan

## Status (updated 2026-07-05)

- **Phase 0**: done except `SWIFT_VERSION` unification. Parser fixture fixed;
  validation-order tests added; `autoSolve` delay injectable
  (`autoSolveStepDelayNanoseconds`, tests pass zero); the remaining two
  baseline failures (top-down traversal assumptions in
  `testClearBoardResetsState` / `testStepSolveSkipsSolvedRows`) are marked
  `XCTExpectFailure` pending Phase 1 re-pinning.
- **Phase 2 (pulled forward in part)**: `LineSolver` extracted as a pure type
  with design tests; `GameManager.solveRow/solveColumn` delegate to it. The
  `lastSolvedClues` sentinel is GONE — replaced by full-sweep progress
  tracking (`progressMadeDuringSweep` + `completeSweep()`) after a real
  imported puzzle stalled `autoSolve` forever. Stalls display a yellow
  "Beyond Simple Level" and the solve buttons restart from a cleared board.
  (References to the sentinel in Phases 1-2 below are historical.)
- **Authoring Integration**: grid JSON import landed (`PuzzleImportParser`,
  `importGrid`, Import button + drag-and-drop zone); the stalled-state
  relabel landed. Catalog export and step-count recording remain.
- **Not started**: remaining Phase 1 characterization tests, clue-generation
  extraction, Phase 3 export/clipboard extraction, Phases 4-8.

This plan describes how to refactor the nonogram app toward the newer store-oriented SwiftUI architecture without changing behavior accidentally. The guiding rule is simple: every structural move should either be preceded by a characterization test or by a new behavior test that fails for the right reason.

Note on the reference manual: the SwiftUI MV / Store manual is iOS-centric. Its Observation, store-ownership, environment, and testing guidance applies directly to this macOS app; ignore the SwiftData and NavigationStack sections, which are not used here.

## Target Architecture

The target is not "MVVM with different names." The goal is a store-oriented SwiftUI app with explicit state ownership, thin views, and domain behavior that is testable without SwiftUI or AppKit.

The intended end state:

- The app composition root owns the app store with `@State`.
- Long-lived observable state uses Swift Observation (`@Observable`) rather than `ObservableObject`, `@Published`, and `@StateObject`.
- Views read state directly from stores and send user intents through narrow methods.
- Domain rules, solving logic, parsing, export formatting, persistence, and platform side effects are separated.
- Environment usage is narrow and deliberate, mostly for stable dependencies or app-level stores, not fast-changing puzzle data.
- Persistence remains behind protocols/actors and is exercised through fake stores in tests.
- Clipboard/export side effects are isolated behind a small dependency rather than living in puzzle state.

## Current Architecture Snapshot

The current app is close enough to preserve, but not close enough to simply rename types.

Current strengths:

- `GameStateStoring` and `PuzzleLoading` already give test seams for persistence and puzzle loading.
- `GameStateStore` and `FlatFileController` are actors, which is a good concurrency boundary.
- Unit tests already cover much of the behavior: tile cycling, clue updates, persistence, loading, solving, contradiction handling, and bulk clue parsing.
- `SplashView` already performs async startup before showing the main screen.

Current friction points:

- `GameManager` mixes app state, puzzle domain rules, solver state, persistence orchestration, JSON formatting, and AppKit pasteboard writes.
- The app uses `ObservableObject`, `@Published`, `@ObservedObject`, and `@StateObject` instead of `@Observable` and `@State`.
- Views are too broad. `ContentView` owns layout, controls, clue entry, bulk parse submission, status presentation, and command wiring.
- The solver is embedded as private methods on `GameManager`, making it harder to test independent line-solving behavior.
- Save calls are launched with unstructured `Task { await save() }`, which makes ordering and test determinism harder.
- Some tests encode current quirks. Before refactoring, test names and fixtures should distinguish intended behavior from incidental behavior.

## TDD Principles For This Refactor

Use three kinds of tests:

- Characterization tests: lock down behavior that must not change during extraction.
- Design tests: describe the API shape of the new store/service before moving production code.
- Regression tests: capture bugs found during the migration, especially ordering, persistence, and solver edge cases.

Refactor in small vertical slices. Each slice should leave the app building and most tests passing. Avoid a long-lived half-migration where both architectures are active everywhere.

Prefer this loop:

1. Add or tighten tests around one behavior.
2. Run the focused tests and confirm the expected failure if adding new API.
3. Move the smallest unit of production code.
4. Run focused tests.
5. Run the full unit target when the slice is complete.
6. Commit the slice.

## Phase 0: Stabilize The Existing Test Baseline

Goal: make the existing suite trustworthy before architecture work.

Tests to fix or add first:

- Fix `BulkClueEntryTests.testParserRejectsInvalidArray` so the fixture has a valid row count and a negative number, for example `[[1],[-2],[3],[4],[5]]`. The current fixture `[[1],[-2]]` fails today: the parser checks count first, so it returns `.tooFew`, not the asserted `.nonPositiveNumbers`.
- Add parser tests for validation order intentionally:
  - fewer than five arrays returns `.tooFew`;
  - more than forty arrays returns `.tooMany`;
  - a non-multiple of five returns `.notMultipleOfFive`;
  - valid count with zero or negative values returns `.nonPositiveNumbers`.
- Make `autoSolve` deterministic by injecting the per-step delay (a `stepDelay` parameter or an injectable `Clock`) so tests can pass zero. The hardcoded 200ms `Task.sleep` per step makes solver tests slow as grids grow.
- Unify `SWIFT_VERSION` across targets (the project currently mixes 5.0 and 6.0). The `@Observable` + `@MainActor` migration behaves differently under Swift 6 strict concurrency; settle the language mode now rather than debugging concurrency diagnostics mid-migration.
- Separate unit tests from UI tests in local commands. The UI test target should not be required for every refactor slice.

Definition of done:

- The unit test target can run from Xcode.
- Any failing tests are documented as known failures with specific causes.
- The parser fixture issue is resolved before moving architecture.

Suggested command:

```sh
xcodebuild test -project nonogramSolver-July2025.xcodeproj -scheme nonogramSolver-July2025 -destination platform=macOS -only-testing:nonogramSolver-July2025Tests
```

## Phase 1: Characterize Domain Behavior

Goal: protect current puzzle behavior before extracting it from `GameManager`.

Add focused tests for `PuzzleGrid` and clue generation:

- A new grid has the requested dimensions and all cells unmarked.
- Tapping a cell cycles `unmarked -> filled -> empty -> unmarked`.
- Filled runs produce row and column clues correctly:
  - no filled cells gives an empty clue array;
  - one contiguous run gives one clue;
  - multiple separated runs give multiple clues.
- Resizing clears the grid but preserves saved clues by row count and column count as current behavior intends.

Add solver characterization tests:

- A line with clue `[3]` in length 5 marks the middle cell filled when solving common cells.
- A line with clue `[1, 1]` in length 3 marks the middle cell empty when all valid permutations agree.
- Existing `.filled` and `.empty` constraints are respected.
- Impossible clues return a contradiction result instead of mutating partial state.
- Traversal order is pinned: rows are solved bottom-up (`previousUnsolvedRow(before:)`), columns left-to-right, alternating row phase then column phase. This order is user-visible via highlighting and step counts, and every step-count assertion depends on it.
- The unsolvable-loop detection mechanism itself has a test. Detection works by comparing the `lastSolvedClues` string sentinel (`"R5"` / `"C3"`) against the next highlighted line, and the sentinel is initialized to `"R\(grid.rows)"` in three places. This is the piece most likely to break silently during extraction.

Characterize the current quirks. Two decisions have been made (driven by the puzzle-authoring workflow with `nonogramImageCreator` — see "Authoring Integration" below):

- **Sticky unsolvable state.** Once `unsolvableByStep` is set, editing a clue via `updateRowClue` / `updateColumnClue` does not reset it; only `clearBoard()` does. Because the UI disables both solve buttons on `unsolvableByStep`, a user who fixes a clue still cannot solve without clearing the board. `tap()` likewise does not reset contradiction or unsolvable state. This remains a latent UX bug to resolve during the store redesign. Related decision (made): the state's *meaning* is "no further progress with line logic," not "invalid puzzle" — in the authoring workflow a stalled puzzle is a candidate for a harder difficulty tier, not a broken one. Rename/relabel accordingly during Phase 4.
- **Tap overwrites hand-entered clues — DECIDED: intended behavior.** Tapping a tile recomputes that row's and column's clues from grid contents. This is the app's editor mode: the authoring workflow imports a candidate matrix, hand-edits it by tapping with live clue derivation, then clears the board (clues are preserved) and solves. Pin with a characterization test as intended behavior, and design the store so grid-editing and clue-solving modes coexist cleanly.

Important: these tests should target new pure types as soon as they exist. At first, they may call `GameManager`; after extraction, move them down to the domain layer.

Definition of done:

- Solver and clue-generation behavior has tests independent of UI views.
- The intended contradiction behavior is explicit.
- Traversal order and loop detection are pinned.
- Each quirk above has either a characterization test or a documented decision to change it.

## Phase 2: Extract Pure Domain Types

Goal: move non-UI puzzle rules out of the observable store.

Introduce pure domain helpers:

- `PuzzleGrid` remains a value type.
- `PuzzleClueGenerator` or `PuzzleGrid.clues(forRow:)` / `clues(forColumn:)` handles clue derivation.
- `LineSolver` handles line permutation and common-cell deduction.
- `PuzzleSolver` coordinates row/column solving at the domain level, returning a result instead of directly mutating published UI state.

Write tests before each extraction:

- `LineSolverTests` should cover valid permutations, shared-cell deductions, and contradictions.
- `PuzzleClueGeneratorTests` should cover row/column clue derivation.
- `PuzzleSolverTests` should cover one-step results without any SwiftUI store.

Production move:

- Copy the current private solver logic into the new type.
- Make `GameManager.stepSolve()` delegate to the new solver.
- Keep `GameManager` API stable while tests are migrated.
- Treat replacing the `lastSolvedClues` string sentinel with a real "progress since last full sweep" flag as an intentional, separate redesign step — not an incidental cleanup during extraction. Extract first with the sentinel intact and its characterization test passing; redesign it in its own commit.

Definition of done:

- Solver tests do not instantiate `GameManager`.
- `GameManager` no longer owns the core permutation algorithm.
- Existing app behavior is unchanged.

## Phase 3: Extract Side Effects

Goal: separate platform operations from puzzle state.

Introduce protocols:

```swift
protocol ClipboardWriting {
    func copy(_ string: String)
}

protocol PuzzleExporting {
    func gridJSON(from grid: PuzzleGrid) -> String
    func cluesJSON(rowClues: [[Int]], columnClues: [[Int]]) -> String
}
```

Tests:

- `PuzzleExportingTests` should verify grid JSON and clue JSON formatting without AppKit.
- A fake clipboard writer should verify that export commands send the expected string.

Production move:

- Move `NSPasteboard` code into `PasteboardClipboardWriter`.
- Move JSON formatting out of `GameManager`.
- Replace `copyGridToClipboard()` and `copyCluesToClipboard()` internals with dependency calls.

Definition of done:

- The state store no longer imports AppKit.
- Export formatting is deterministic and unit tested.
- Clipboard side effects are mockable.

## Phase 4: Define The Store Boundary

Goal: replace the oversized `GameManager` with a store API that expresses user intent.

Start with a compatibility layer rather than a full rewrite.

Proposed store split:

- `PuzzleStore`: owns grid, row clues, column clues, size changes, clue edits, board clearing, and persistence coordination.
- `SolverStore` or `SolvingSession`: owns highlighted row/column, step count, contradiction state, unsolvable state, and auto-solve orchestration.
- `PuzzleImportExportStore` or small services: owns bulk clue parsing and export commands if that state remains substantial.

**Default to one `PuzzleStore`.** The solver mutates `grid.tiles` directly, and solver state (`highlightedRow`, `errorRow`, `lastSolvedClues`) is entangled with grid and clue state — the tap-overwrites-clues interaction cuts right across a `PuzzleStore` / `SolverStore` boundary. Extract `LineSolver` and `PuzzleSolver` as pure types (Phase 2), but keep a single store unless a split clearly earns its keep afterward. Bounded contexts should reduce coupling, not create ceremony.

Design tests:

- Initial store loads saved state when present.
- Initial store loads bundled puzzle when no saved clues exist.
- Size changes preserve clue sets by compatible row/column count.
- Tapping a tile updates the grid and clues.
- Editing a contradiction row/column clears the relevant contradiction marker.
- Clear board resets solver state and preserves clues.
- Save is called after mutating commands, with deterministic tests using an in-memory store.

Production move:

- Create `PuzzleStore` while leaving `GameManager` in place.
- Move one command at a time behind tests.
- When `PuzzleStore` covers all commands, replace `GameManager` references in views.

Definition of done:

- Store tests describe user intents, not view mechanics.
- Persistence tests use fake actors/stores.
- `GameManager` is either deleted or reduced to a temporary adapter with no unique behavior.

## Phase 5: Migrate To Swift Observation

Goal: adopt the architecture document's state ownership model after behavior is protected.

The deployment target is macOS 15.5, so `@Observable` is available without conditionals.

Expected changes:

- Replace `class GameManager: ObservableObject` with `@Observable @MainActor final class PuzzleStore` or equivalent.
- Replace `@Published` properties with ordinary stored properties.
- Replace `@StateObject` in root ownership with `@State`.
- Replace `@ObservedObject` in child views with direct store parameters, bindable substate, or focused value bindings.
- Delete the `objectWillChange.send()` call in `set(rows:columns:)` — it does not exist under `@Observable`. Its comment claims it prevents a UI race during resizes; re-verify picker-driven resizes manually after migration, since Observation's invalidation granularity differs from `ObservableObject`.

Notes on the current views:

- `ContentView` currently uses `@StateObject(wrappedValue:)` with an externally built manager — a known anti-pattern, since the wrapped value is only captured on first init. Migrating to a plain `let manager` property fixes this for free.
- `SplashView` already owns the manager with `@State private var manager: GameManager?` and builds it asynchronously via `GameManagerBuilder` — this already matches the target composition-root pattern and needs little change.

Tests:

- Store unit tests should not depend on observation.
- Add light view tests only if the project has an established pattern for them. Otherwise, verify manually in Xcode after unit tests pass.

Production move:

- Migrate one view subtree at a time:
  - `SplashView` / composition root;
  - `ContentView`;
  - `NonogramGridView`;
  - clue entry views.
- Avoid environment injection for fast-changing grid cell data. Passing a store or focused value bindings is clearer and avoids broad invalidation.

Definition of done:

- No app code uses `ObservableObject`, `@Published`, `@ObservedObject`, or `@StateObject` for the main puzzle state.
- The app root owns the store with `@State`.
- Child views are smaller and receive only the state/actions they need where practical.

## Phase 6: Reshape Views Around Features

Goal: make view structure match user workflows.

Suggested view decomposition:

- `PuzzleScreen`: top-level screen and navigation title.
- `PuzzleToolbar` or `PuzzleCommandBar`: export, solve, step, clear.
- `GridSizeControls`: row/column pickers.
- `SolvingStatusView`: contradiction/unsolvable/solved/progress messaging.
- `ClueEditorPanel`: row and column clue editing.
- `BulkClueInput`: pasted JSON input and validation message.
- `PuzzleGridView`: grid display and interaction only.

Tests:

- Keep view logic minimal enough that most behavior remains covered by store tests.
- If a subview owns local presentation state, test the parser/service behind it, not the SwiftUI rendering unless a bug warrants it.

Production move:

- Extract one subview at a time with no behavior changes.
- Prefer explicit bindings or small action closures over giving every leaf the full store.
- Keep fast-changing cell state out of the environment.

Definition of done:

- `ContentView` is small enough to scan.
- Each subview has one job.
- Domain behavior still lives outside SwiftUI views.

## Phase 7: Improve Async And Persistence Semantics

Goal: remove hidden ordering problems from unstructured saves.

Current pattern:

```swift
Task { await save() }
```

This is convenient but makes tests and ordering less explicit. There are eight such call sites in `GameManager`.

A concrete instance: `loadRowClues` / `loadColumnClues` call `set(rows:columns:)` (which fires `Task { await save() }`) and then fire a second `Task { await save() }` after mutating clues — two unordered tasks racing to persist different snapshots. Phase 0/1 tests around bulk loading should be aware that the persisted state is currently nondeterministic mid-flight; the fix lands here.

Preferred options:

- Make mutating store commands `async` where the caller should wait for persistence.
- Or introduce a debounced save coordinator actor if saving after every edit becomes expensive.
- Or keep fire-and-forget saves only behind a named dependency, so tests can observe scheduled saves deterministically.

Tests:

- Mutating commands persist exactly the expected state.
- Rapid clue edits do not save stale state after newer state.
- Loading failure falls back to a predictable initial puzzle.

Definition of done:

- Save behavior is explicit in store tests.
- No production code relies on incidental task ordering.

## Phase 8: Retire Transitional Code

Goal: remove old architecture after the new one has proven itself.

Checklist:

- Delete `GameManager` if fully replaced.
- Delete obsolete builder code or rename it as the composition root/store factory.
- Update `DEVELOPER_GUIDE.md` and `FILE_OVERVIEW.md`.
- Update previews to construct the new store or use preview fixtures.
- Rename tests from `GameManagerTests` to store/domain test names.
- Remove obsolete comments that describe refactor scaffolding.

Definition of done:

- No compatibility adapter remains unless it has a clear purpose.
- Documentation matches the code.
- Unit tests pass.

## Authoring Integration (Feature Work Alongside the Refactor)

The app doubles as the **editor and verifier** in the puzzle-authoring
workflow with `nonogramImageCreator` (see that repo's `GAME_PLAN.md`; the
shared data contract is `docs/json-format.md` there). This is feature work,
not refactoring, but the refactor should design for it. Features, roughly in
order of need:

- **Grid JSON import.** The mirror of the existing `gridJSON` export: paste or
  load a 0/1 matrix, populate the grid tiles, and let clue derivation run.
  Validate the 5-40 multiple-of-5 size constraint on import. Natural home:
  alongside the Phase 3 export services and the Phase 4 store commands.
- **Blank-line contract.** Imported/exported puzzles must contain no empty
  rows or columns (the parser rejects `[0]`; the step solver treats `[]` as
  missing input). Enforce at import; the long-term plan may add coordinated
  `[0]` support instead.
- **Relabel the stalled state.** `unsolvableByStep` means "no further progress
  with line logic." Rename the property/UI text during Phase 4 so authors do
  not read it as "invalid puzzle."
- **Surface the step count as crude difficulty.** `solvingStepCount` at
  completion approximates the literature's sweep-count difficulty metric.
  Record/display it for accepted puzzles so the catalog gets a difficulty
  ordering for free.
- **Catalog export.** Accepted puzzles (grid + clues JSON) are saved into the
  repo's `catalog/` folder — the catalog of record for the game app.
- **Uniqueness note.** If the line solver fully completes a puzzle, the
  solution is provably unique (every deduced cell is forced). Stage 1 of the
  authoring plan publishes only line-solvable puzzles, so no uniqueness
  validator is needed until harder tiers are admitted (long-term plan).

Sequencing: grid import and catalog export can land any time after Phase 3
(export/side-effect extraction); the relabel belongs in Phase 4's store API
design; nothing here blocks Phases 0-2.

## Suggested Commit Sequence

Keep commits small and reviewable:

1. Fix current test baseline and parser fixture; unify `SWIFT_VERSION`; make the `autoSolve` delay injectable.
2. Add clue-generation and line-solver characterization tests, including traversal order, loop detection, and the quirks (sticky unsolvable state, tap-overwrites-clues).
3. Extract `LineSolver`.
4. Extract clue generation.
5. Extract JSON export and clipboard writing.
6. Introduce `PuzzleStore` behind existing behavior.
7. Move persistence orchestration into the store boundary.
8. Migrate store to `@Observable`.
9. Replace `@StateObject` / `@ObservedObject` view wiring.
10. Split `ContentView` into feature views.
11. Update docs and remove transitional code.

Each commit should pass focused tests. Every two or three commits, run the full unit target.

## Risk Areas

Solver correctness is the highest-risk area. Extract it before changing observation or views. The `lastSolvedClues` string sentinel that drives unsolvable-loop detection is the most fragile piece — characterize it before touching it.

Persistence ordering is the second-highest risk. The current unstructured save tasks may hide races (see the double-save in `loadRowClues` / `loadColumnClues` noted in Phase 7). Tests should make expected save behavior explicit before changing it.

The tap/clue dual-mode interaction is a design decision hiding in the code: tapping recomputes clues from the grid, silently destroying hand-entered clues. Any store split or command redesign must take an explicit position on this. Related: solver stop states (`unsolvableByStep`, contradiction flags) are only reset by `clearBoard()`, not by clue edits or taps — decide whether that is intended before porting it.

View invalidation is the third risk. Moving to environment-based stores can accidentally broaden updates. Avoid placing rapidly changing grid state in environment values.

Bulk clue loading changes grid dimensions as a side effect. Tests should pin down whether loading rows should change only row count, whether loading columns should change only column count, and how clues are preserved across sizes.

Clipboard export is user-visible but currently coupled to `GameManager`. Isolate it early so later state refactors do not carry AppKit dependencies through the domain layer.

## Recommended First Slice

Start with the smallest useful TDD slice:

1. Fix `BulkClueEntryTests.testParserRejectsInvalidArray`.
2. Add `LineSolverTests` for a single clue, multiple clues, existing constraints, and contradiction.
3. Extract `LineSolver` from `GameManager`.
4. Make `GameManager.solveRow` and `solveColumn` delegate to `LineSolver`.
5. Run parser tests, solver tests, and `GameManagerTests`.
6. Commit.

This slice reduces risk immediately because the most complex logic becomes pure and independently testable before any SwiftUI architecture migration begins.
