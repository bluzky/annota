# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a native macOS canvas drawing application built with SwiftUI. The app provides a FigJam-like interface for drawing text, rectangles, and circles on a canvas, with support for text inside shapes.

## Development Commands

```bash
# Build
xcodebuild -scheme texttool -configuration Debug build

# Run all tests
xcodebuild test -scheme texttool

# Run only unit tests
xcodebuild test -scheme texttool -only-testing:texttoolTests

# Run a specific test
xcodebuild test -scheme texttool -only-testing:texttoolTests/texttoolTests/example

# Clean
xcodebuild -scheme texttool clean
```

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed system design, protocols, and implementation phases.

### State Management
- `CanvasViewModel.swift`: @MainActor ObservableObject - single source of truth for all canvas state
  - Published arrays: `textObjects`, `rectangleObjects`, `circleObjects`
  - Tool state: `selectedTool`, `selectedObjectId`, `activeTextSize`, `activeColor`, `autoResizeShapes`
  - Drag state: `dragStartPoint`, `currentDragPoint` (for shape preview during drag)
  - Hit testing via `selectObject(at:)` checks objects in reverse z-order

### Data Models (all structs with `contains(_ point:)` hit testing)
- `TextObject`: position, text, fontSize, color, isEditing
- `RectangleObject`: position, size, color, text, isEditing, autoResizeHeight
- `CircleObject`: position, size, color, text, isEditing, autoResizeHeight (uses ellipse equation for hit testing)
- `DrawingTool`: enum with `.select`, `.text`, `.rectangle`, `.circle`

### Views
- `ContentView.swift`: VStack with ToolbarView + CanvasView, owns CanvasViewModel via @StateObject
- `CanvasView.swift`: GeometryReader/ZStack rendering, DragGesture with minimumDistance: 0 (distance < 5 = click)
- `TextObjectView.swift`, `RectangleObjectView.swift`, `CircleObjectView.swift`: Conditional TextField/Text rendering based on isEditing
- `FloatingFormatBar.swift`: Rich text formatting popup (font size, bold, italic, color) with `TextAttributes` struct
- `AutoGrowingTextView.swift`: NSViewRepresentable wrapping NSTextView for auto-expanding text input

### Key Patterns

**Gesture Handling**: Single DragGesture handles both clicks and drags - distance check distinguishes them. Tool-based filtering in handlers.

**Text in Shapes**: Rectangles and circles support embedded text with auto-resize height when `autoResizeHeight` is true. Text editing uses same isEditing pattern as TextObject.

**Object Updates**: Mutable structs updated via array index assignment (e.g., `textObjects[index].text = newText`).

**Coordinate System**: SwiftUI natural (top-left origin), absolute CGPoint positions, `.position()` modifier for placement.

## Issue Tracking

This project uses **bd (beads)** for issue tracking.
Run `bd prime` for workflow context, or install hooks (`bd hooks install`) for auto-injection.

**Quick reference:**
- `bd ready` - Find unblocked work
- `bd create "Title" --type task --priority 2` - Create issue
- `bd close <id>` - Complete work
- `bd sync` - Sync with git (run at session end)

For full workflow details: `bd prime`

## Testing

Uses Swift Testing framework (not XCTest):
```swift
import Testing
@testable import texttool

@Test func example() async throws {
    #expect(condition)
}
```
