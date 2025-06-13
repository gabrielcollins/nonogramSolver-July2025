# Nonogram macOS Solver App - Application Development Plan

## Overview
This document outlines the initial development steps for a macOS companion application built with SwiftUI
and Swift 6. The app provides a simple interface for solving Nonogram puzzles. It reuses the JSON puzzle
format from the iOS project but does not load any puzzles at launch. Future iterations will expand the
feature set, but this plan focuses on the minimal functionality required to start development.

## Goals
1. **SwiftUI macOS Target**: Create a new macOS app using the same project organization as the iOS codebase.
2. **Flat-File Persistence**: Adopt the JSON flat-file system and store-based data flow defined in the iOS app.
3. **Strict Concurrency**: Follow Swift 6 strict concurrency rules for actors and `@MainActor` isolation.
4. **Simple Grid Interface**: Display a light gray puzzle grid without textures, pan, zoom, or complex layering.
5. **Clue Input & Editing**: Allow entry of row and column clues via text fields, persisting the last puzzle state.
6. **Future Auto-Solve**: Include placeholder buttons for "Auto Solve" and "Step Solve" with empty actions.

## App Structure
- **Models**
  - `TileState`: `enum` with cases `.filled`, `.empty`, `.unmarked`.
  - `PuzzleGrid`: Two‑dimensional array of `TileState` values with row and column counts.
  - `GameState`: Persisted structure storing the grid and clue arrays.
- **Services**
  - `GameStateStore`: Saves and loads `GameState` to JSON using a `FlatFileController` actor.
  - `PuzzleService`: Provides sample puzzles from the existing `testing.json` file (no automatic loading yet).
  - `GameManager`: Observable class coordinating grid updates and clue editing.
- **Views**
  - `ContentView`: Hosts a `NonogramGridView` and puzzle controls inside a `NavigationStack`.
  - `NonogramGridView`: Draws the puzzle grid using black lines with thicker lines every five cells.
  - `ClueEntryView`: Text fields for row and column clues with space‑separated numbers.
  - `Toolbar`: Dropdowns for selecting row and column counts (5–40, increments of 5) plus the two solve buttons.

## Initial Feature Set
1. **Default Puzzle Size**
   - Launch with a 20x15 grid of `.unmarked` tiles.
   - Row and column counts stored in `GameManager` and persisted in `GameState`.
2. **Grid Interaction**
   - Clicking a tile cycles through `.filled` (black), `.empty` (white with small X), and `.unmarked` (white).
3. **Clue Input**
   - Users enter clues as strings such as `"3 5 1 1"`. The app splits them into integer arrays for each row or column.
   - Clues persist across launches via `GameStateStore`.
4. **Puzzle Data Sharing**
   - Copy `testing.json` into the macOS target’s `Data` folder for future puzzle loading.
   - Do not load puzzle files automatically in the initial version.
5. **Toolbar Controls**
   - Row count and column count dropdowns using `Picker` with values 5–40 (step 5).
   - "Auto Solve" and "Step Solve" buttons stubbed with empty methods on `GameManager` for now.
6. **State Persistence**
   - Save the grid and clues whenever they change. On launch, load the last saved state if available.
7. **Testing**
   - Create unit tests with XCTest for grid logic and persistence.
   - Add basic UI tests verifying grid interactions and clue entry on macOS 15.4.

## Future Work
- Implement puzzle loading from `testing.json` and allow selecting a puzzle to prefill clues and solutions.
- Add solving algorithms to power the auto‑solve and step‑solve buttons.
- Consider theming support using the existing `ThemeManager` architecture.
- Expand the UI with progress indicators and puzzle metadata once core features are stable.

