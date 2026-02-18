# Repository Guidelines

## Project Structure & Module Organization
The SwiftUI entry point lives in `texttool/texttoolApp.swift`, with feature code split between `Models/` (shape definitions), `ViewModels/` (`CanvasViewModel` state machine), and `Views/` (SwiftUI surfaces such as `CanvasView` and `ToolbarView`). Assets are stored in `texttool/Assets.xcassets`, while previews and sample types (for example `Item.swift`) stay beside the feature they exercise. Unit targets reside under `texttoolTests/` and UI automation fixtures under `texttoolUITests/`; keep new test helpers in those directories to avoid leaking into the shipping target.

## Build, Test, and Development Commands
Use Xcode 15+ for day-to-day iteration: `xed texttool.xcodeproj` opens the project with the correct schemes. Automated builds and CI can rely on `xcodebuild -scheme texttool -destination "platform=iOS Simulator,name=iPhone 15" build`. Run all tests through `xcodebuild test -scheme texttool -destination "platform=iOS Simulator,name=iPhone 15"`, or target just the async unit suite with `xcodebuild test -only-testing:texttoolTests`.

## Coding Style & Naming Conventions
Adopt Swift 5.9+ defaults: four-space indentation, `camelCase` for properties/functions, `UpperCamelCase` for types, and descriptive enum cases (see `DrawingTool`). Prefer value types for view state, keep SwiftUI `View` bodies declarative, and document non-trivial helpers with a single-line comment. Observable models should stay `@MainActor`, expose `@Published` properties, and never mutate view state from background threads.

## Testing Guidelines
Unit tests use the new `Testing` package, so wrap scenarios in `@Test` functions and assert via `#expect`. UI smoke tests continue to rely on XCTest (`texttoolUITests/`): add app flows under `texttoolUITests.swift` and performance probes in `texttoolUITestsLaunchTests.swift`. Strive for meaningful names like `testAddingRectangleShowsHandles` and maintain high-level coverage on Canvas interactions before merging.

## Commit & Pull Request Guidelines
Git history currently contains a single conventional subject line ("Initial Commit"), so continue using short, imperative summaries (e.g., "Add circle drag preview"). Group related file changes per commit, reference ticket IDs when available, and avoid WIP commits in shared branches. Pull requests should outline the motivation, list user-visible changes, call out testing evidence/`xcodebuild test` output, and attach screenshots or short clips when UI changes affect Canvas rendering.

## Architecture & State Management
The app follows a lightweight MVVM split where `CanvasViewModel` orchestrates editing state and view structs focus on rendering. Add new tools or formatting controls by extending the model first, then threading bindings into `ToolbarView` and the relevant object views to keep gesture handling centralized in `CanvasView`.

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
