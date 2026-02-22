# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a native macOS canvas drawing application built with SwiftUI, featuring a FigJam-like interface with an infinite canvas, multi-selection, pan/zoom, and comprehensive annotation tools.

**Key Architecture:** The project consists of two targets:
1. **AnotarCanvas** - Reusable SwiftUI framework for canvas functionality
2. **Annota** - macOS application built on AnotarCanvas

## Development Commands

```bash
# Build framework
xcodebuild -scheme AnotarCanvas -configuration Debug build

# Build application
xcodebuild -scheme Annota -configuration Debug build

# Run all tests
xcodebuild test -scheme Annota

# Run only unit tests
xcodebuild test -scheme Annota -only-testing:AnnotaTests

# Clean
xcodebuild -scheme Annota clean
```

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed system design and [docs/AnotarCanvas-API.md](docs/AnotarCanvas-API.md) for framework API reference.

### AnotarCanvas Framework (Reusable Core)

**State Management:**
- `CanvasViewModel.swift`: @MainActor ObservableObject - single source of truth
  - `objects: [AnyCanvasObject]` - Unified heterogeneous object storage
  - `selectedTool: DrawingTool` - Current tool (lightweight value type)
  - `selectionState: SelectionState` - Multi-selection support
  - `viewport: ViewportState` - Pan/zoom state
  - `dragStartPoint`, `currentDragPoint` - Preview state

**Object Model (Protocol-Based):**
- `CanvasObject` protocol: Base protocol for all canvas objects
  - Required: `id`, `position`, `size`, `rotation`, `zIndex`, `isLocked`
  - Methods: `contains(_:)`, `boundingBox()`, `hitTest(_:threshold:)`
- `AnyCanvasObject`: Type-erased wrapper for heterogeneous storage
- Capability protocols: `TextContentObject`, `StrokableObject`, `FillableObject`
- Built-in objects: `TextObject`, `ShapeObject`, `LineObject`, `ImageObject`

**Tool Plugin System:**
- `CanvasTool` protocol: All tools implement this
- `DrawingTool`: Lightweight identifier (struct with `id: String`)
- `ToolRegistry`: Dynamic tool registration (singleton)
- `ToolManifest<Obj>`: Bundles tool + views + codable for new object types
- Tool identities declared per-file via extensions (no central enum)

**Shape Tools (Each Shape = Separate Tool):**
- `RectangleTool`, `OvalTool`, `TriangleTool`, `DiamondTool`, `StarTool`
- Each inherits from `BaseShapeTool`
- Each defines its own SVG path geometry
- `ShapeObject` stores `svgPath: String` and `toolId: String`

**Views:**
- `CanvasView`: Main rendering view (tool-agnostic)
- `ObjectViewRegistry`: Maps object types to view factories
- Object views: `ShapeObjectView`, `TextObjectView`, `LineObjectView`, etc.
- `SelectionBoxView`: Multi-object selection with resize/rotate handles

### Annota Application Layer

**Application-Specific:**
- `ToolbarView`: Tool buttons, shape picker, color pickers
- `ContentView`: Composes toolbar + canvas
- `AppState`: Export functionality, file commands
- Icons, keyboard shortcuts, UI presentation

### Key Patterns

**Plugin Architecture**: Add new tools by implementing `CanvasTool` protocol and registering with `ToolRegistry`. No modifications to core framework files required. See [docs/adding-a-tool.md](docs/adding-a-tool.md).

**Gesture Handling**: Single DragGesture with distance threshold (< 5px = click). CanvasView delegates to tools via `ToolRegistry`.

**Object Storage**: All objects stored in unified `[AnyCanvasObject]` array. Type-safe access via `.asType(_:)` or pattern matching.

**Viewport**: Pan/zoom via `ViewportState`. All rendering transformed by viewport scale/offset.

**Selection**: Multi-selection via Shift+click and marquee drag. Selection box supports resize (corners/edges) and rotation (outside corners).

**Coordinate System**: SwiftUI natural (top-left origin), canvas coordinates transformed by viewport.

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
@testable import Annota

@Test func example() async throws {
    #expect(condition)
}
```
