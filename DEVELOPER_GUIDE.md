# Nonogram Solver Developer Guide

This document captures the current conventions, architecture and specifications used in the **nonogramSolver-July2025** macOS project. The information here is intended for developers planning to continue work on the codebase.

## Project Goals and Specifications
- **Platform**: macOS app written in Swift 6 using SwiftUI.
- **Model-Driven Data Flow**: The UI observes a single `GameManager` object. Views do not own their own state beyond presentation logic.
- **Persistence**: A `GameStateStore` actor conforming to `GameStateStoring` saves and loads the puzzle state as JSON using `FlatFileController` for atomic disk I/O.
- **Strict Concurrency**: All state mutations occur on actors or via `@MainActor` objects. `GameManager` is marked `@MainActor`. Persistence actors isolate file operations.
- **UI Features**: A basic grid view with row/column clues, controls for puzzle size, and placeholder "Auto Solve" and "Step Solve" buttons.
- **Contradiction Detection**: The step solver halts when clues conflict with the current board and highlights the offending row or column in red.
- **Builder Pattern**: `GameManagerBuilder` constructs and loads the model before any view accesses it, preventing concurrency issues on startup.
- **Dependency Injection**: Persistence and puzzle loading use the `GameStateStoring` and `PuzzleLoading` protocols so different implementations can be supplied in tests or future features.
- **Testing**: Unit tests exist for tile cycling and persistence. UI tests are present but still contain template code.

These align with the original _MacOS Solver App Development Plan_ in the repository.

## Architectural Conventions
- **`GameManager`**
  - `@MainActor` observable object that owns the `PuzzleGrid` and clue arrays.
  - Exposes methods to mutate the grid (`tap`), update clues, and change puzzle size.
  - Asynchronously saves the state after each mutation.
  - Dependencies for persistence are injected through the `GameStateStoring` protocol for easier testing.
  - Detects contradictions during step solving. When no valid line permutation exists for a row or column, `contradictionRow` or `contradictionColumn` is set and solving halts until the user updates the clues.
- **`GameStateStore` & `FlatFileController`**
  - `GameStateStore` implements `GameStateStoring`; `FlatFileController` performs disk I/O with atomic writes.
  - File name is fixed at `gamestate.json` in the user documents directory.
  - `PuzzleService` implements `PuzzleLoading` to read bundled puzzle data used during initialization.
- **View Layer**
  - The entry point struct is `NonogramSolverJuly2025App`.
  - `SplashView` loads the game state asynchronously using `GameManagerBuilder`.
  - `ContentView` hosts the main UI and injects the loaded `GameManager` via `@StateObject`.
  - `NonogramGridView` composes smaller subviews from `NonogramGridComponents.swift` to render the puzzle grid and handle taps.
  - `ClueEntryView` is provided for full clue editing but is not currently used by the main UI.
- **Coding Style**
  - Follows Swift naming conventions (`camelCase` for methods and variables, `PascalCase` for types).
  - Actors and async methods use Swift 6 concurrency primitives (`async`, `await`).
  - UI previews are defined using `#Preview` blocks for SwiftUI.

## Future Work Notes
- Implement UI tests verifying grid interaction and clue entry as described in the plan.
- Add puzzle loading from bundled JSON files and solving algorithms for the stubbed buttons.
- Consider theming and additional UI polish once core features are stable.
