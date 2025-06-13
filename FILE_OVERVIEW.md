# Directory and File Overview

This document describes the layout of the repository and the purpose of each top-level file.

## Root Level
- `MacOS_Solver_App_Development_Plan.md` – Original specification detailing the minimal feature set and architecture for the macOS Nonogram solver.
- `DEVELOPER_GUIDE.md` – Developer guide summarizing conventions and architecture (this file is generated).
- `nonogramSolver-July2025.xcodeproj/` – Xcode project containing build settings for the macOS target and test targets.
- `nonogramSolver-July2025/` – Source directory for the application.
- `nonogramSolver-July2025Tests/` – Unit test target.
- `nonogramSolver-July2025UITests/` – UI test target.

## `nonogramSolver-July2025/` Source Files
- `nonogramSolver_July2025App.swift` – Application entry point. The main struct `NonogramSolverJuly2025App` creates the window and shows `SplashView`.
- `SplashView.swift` – Loading view that asynchronously builds the `GameManager` using `GameManagerBuilder` before showing `ContentView`.
- `GameManagerBuilder.swift` – Builder struct that injects a `GameStateStoring` and `PuzzleLoading` dependency when constructing `GameManager` and loads saved or sample puzzles.
- `GameManager.swift` – `@MainActor` observable object that owns the puzzle grid and clues. Dependencies are passed in via `GameStateStoring`.
- `Services.swift` – Defines `GameStateStoring` and `PuzzleLoading` protocols alongside `FlatFileController`, `GameStateStore`, and `PuzzleService` implementations.
- `NonogramGridView.swift` – Composes `ColumnCluesView`, `RowCluesView`, and `GridCellView` from `NonogramGridComponents.swift` to draw the puzzle grid.
- `NonogramGridComponents.swift` – Helper views (`GridCellView`, `ColumnCluesView`, and `RowCluesView`) plus `GridStyle` utilities.
- `Data/testing.json` – Sample puzzle data in JSON format for future puzzle loading.
- `Assets.xcassets/` – Asset catalog containing the app icon and color sets.
- `nonogramSolver_July2025.entitlements` – Sandbox and capability settings for the macOS target.

## Test Targets
- `nonogramSolver-July2025Tests/nonogramSolver_July2025Tests.swift` – Unit tests covering tile cycling, persistence, puzzle loading, and grid resizing.
- `nonogramSolver-July2025UITests/nonogramSolver_July2025UITests.swift` – Basic UI test asserting the Auto Solve button exists.
- `nonogramSolver-July2025UITests/nonogramSolver_July2025UITestsLaunchTests.swift` – Template launch performance test.

