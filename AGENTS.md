# Repository Guidelines

## Project Overview
This is a native macOS canvas drawing application built with SwiftUI, providing a FigJam-like interface for drawing text, rectangles, and circles on an infinite canvas. The app uses the Swift Testing framework (not XCTest) for unit tests.

## Project Structure & Module Organization
The SwiftUI entry point lives in `texttool/texttoolApp.swift`, with feature code split between:
- `Models/` - Data models and protocols (`TextObject`, `RectangleObject`, `CircleObject`, `CanvasObject` protocol)
- `ViewModels/` - State management (`CanvasViewModel` as @MainActor ObservableObject)
- `Views/` - SwiftUI surfaces (`CanvasView`, `ToolbarView`, object rendering views)
- `Models/Protocols/` - Protocol definitions (`CanvasObject`, `TextContentObject`, `FillableObject`, `StrokableObject`)

Assets are stored in `texttool/Assets.xcassets`, while previews and sample types (e.g., `Item.swift`) stay beside the feature they exercise. Unit targets reside under `texttoolTests/` and UI automation fixtures under `texttoolUITests/`.

## Build, Test, and Development Commands

### Building
```bash
# Open in Xcode 15+
xed texttool.xcodeproj

# Debug build
xcodebuild -scheme texttool -configuration Debug build

# Clean build artifacts
xcodebuild -scheme texttool clean

# Release build
xcodebuild -scheme texttool -configuration Release build
```

### Running Tests (Swift Testing Framework)
```bash
# Run all tests
xcodebuild test -scheme texttool

# Run only unit tests (exclude UI tests)
xcodebuild test -scheme texttool -only-testing:texttoolTests

# Run specific test file
xcodebuild test -scheme texttool -only-testing:texttoolTests/ViewportStateTests

# Run specific test function
xcodebuild test -scheme texttool -only-testing:texttoolTests/ViewportStateTests/defaultState

# Run UI tests only
xcodebuild test -scheme texttool -only-testing:texttoolUITests
```

### Testing Guidelines
Tests use Swift Testing framework (not XCTest):
```swift
import Testing
@testable import texttool

struct ExampleTests {
    @Test func specificBehavior() async throws {
        #expect(condition)
    }
}
```

Unit tests use `@Test` functions with `#expect` for assertions. UI tests use XCTest (`texttoolUITests/`). Strive for meaningful test names like `testAddingRectangleShowsHandles` or `screenToCanvasWithOffset` and maintain coverage on core Canvas interactions.

## Coding Style & Naming Conventions

### Formatting & Indentation
- Four-space indentation (no tabs)
- Swift 5.9+ language features
- Maximum line length: ~100 characters (soft limit, readability-focused)
- Trailing commas in multi-line arrays/dictionaries

### Naming Conventions
- `camelCase` for properties, functions, and variables
- `UpperCamelCase` for types (structs, classes, enums, protocols)
- Descriptive enum cases (e.g., `.select`, `.rectangle`, `.circle` from `DrawingTool`)
- Boolean properties use `is` prefix (e.g., `isEditing`, `isSelected`, `isLocked`)
- Computed properties should read naturally (e.g., `selectedIds`, `isAnyObjectEditing`)

### Type System
- Prefer value types (structs) for data models
- Use classes only when reference semantics are required (ViewModels)
- Protocol-oriented design: `CanvasObject` protocol with default implementations
- Use `@MainActor` for all ObservableObject ViewModels
- Models should conform to `Identifiable` for SwiftUI `ForEach` compatibility

### Import Organization
- Group imports: standard library, third-party, local modules
- Sort alphabetically within groups
- Example:
```swift
import SwiftUI
import CoreGraphics
import Combine
@testable import texttool
```

### Error Handling
- Use `guard` statements for early returns with descriptive messages
- Return optionals for non-critical failures
- Avoid force unwrapping (`!`) - use optional binding or `guard let` instead
- For async operations, use Swift concurrency (`async/await`)

### SwiftUI Conventions
- Keep View bodies declarative - avoid imperative logic
- Use `@State`, `@Binding`, `@ObservedObject`, and `@StateObject` appropriately
- Extract complex views into separate view structs
- Use modifiers at point of use - avoid custom modifier proliferation for simple transforms
- Gesture handling: single `DragGesture(minimumDistance: 0)` with distance checks inside handlers

### State Management
- `CanvasViewModel` is the single source of truth for canvas state
- Expose state via `@Published` properties
- Object updates: modify struct via array index assignment (e.g., `objects[index] = AnyCanvasObject(updated)`)
- Never mutate `@Published` properties from background threads (use `@MainActor`)
- Transient state (drag previews): use `@Published` properties on ViewModel

### Code Comments
- Document non-trivial logic with single-line comments
- No doc comments for obvious public APIs
- Comments should explain "why" not "what"
- Protocol documentation should describe intent and usage

### Protocol-Based Design
- `CanvasObject`: base protocol for all canvas objects with `contains()`, `boundingBox()`, `hitTest()`
- Use protocol extensions for default implementations
- Feature protocols compose with base (e.g., `TextContentObject`, `FillableObject`)

## Task Management with bd (bead)

This project uses **bd** as the canonical task list. Always use it to track work items — do not rely on in-session memory or TODO comments alone.

```bash
bd status                                    # overview
bd list                                      # open issues
bd ready                                     # unblocked issues ready to start

bd q "Fix oval hit-test edge case"           # quick-capture (outputs ID only)
bd update <id> --status in_progress          # claim a task
bd close <id> --reason "done in Foo.swift"   # mark complete

bd dep add <blocked-id> <blocker-id>         # record ordering dependency
```

Reference issue IDs in commit messages: `git commit -m "Add ShapeObject (texttool-g4y)"`

`bd sync` is part of the mandatory session-end push — see **Landing the Plane** below.

## Commit & Pull Request Guidelines
Git history currently contains a single conventional subject line ("Initial Commit"), so continue using short, imperative summaries (e.g., "Add circle drag preview"). Group related file changes per commit, reference issue IDs from `bd` when available (e.g., `texttool-g4y`), and avoid WIP commits in shared branches. Pull requests should outline the motivation, list user-visible changes, call out testing evidence/`xcodebuild test` output, and attach screenshots or short clips when UI changes affect Canvas rendering.

## Architecture & State Management
The app follows a lightweight MVVM split where `CanvasViewModel` orchestrates editing state and view structs focus on rendering. Add new tools or formatting controls by extending the model first, then threading bindings into `ToolbarView` and the relevant object views to keep gesture handling centralized in `CanvasView`.

## Key Implementation Patterns

### Gesture Handling
- Single `DragGesture(minimumDistance: 0)` handles both clicks and drags
- Distance check (`hypot`) distinguishes clicks (< 5pts) from drags
- Tool-based filtering in gesture handlers
- Screen-to-canvas coordinate transformation via `ViewportState`

### Object Hit Testing
- Hit test objects in reverse z-order (highest zIndex first)
- Use `contains()` for point-in-object checks
- Use `hitTest()` for detailed corner/edge detection
- Threshold parameter allows hit testing slightly outside object bounds

### Coordinate Systems
- Canvas coordinates: absolute CGPoint positions on infinite canvas
- Screen coordinates: SwiftUI view-relative points
- `ViewportState` transforms between systems with offset and scale
- All drawing operations use canvas coordinates; gestures start in screen coordinates

### Text in Shapes
- Rectangles and circles support embedded text
- Auto-resize height when `autoResizeHeight` is true
- Text editing uses same `isEditing` pattern as `TextObject`
- `TextContentObject` protocol provides shared text attributes

### Multi-Selection
- `SelectionState` manages selected object IDs as a Set
- Shift+click toggles selection, regular click replaces selection
- Marquee selection (drag in empty space) selects objects in rectangle
- `SelectionBox` calculates bounding box of all selected objects

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