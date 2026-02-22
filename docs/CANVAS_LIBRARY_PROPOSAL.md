# Canvas Library Extraction Proposal

## Overview

Extract the annotation canvas functionality as a reusable library (`AnnotationCanvas`), keeping toolbar, hotkeys, and application-level features in the app target.

---

## Current Architecture

```
texttool (single target)
├── App layer (application)
│   ├── texttoolApp.swift       # Entry point
│   ├── ContentView             # Composes toolbar + canvas
│   ├── AppState                # Export, commands bridge
│   ├── ToolbarView             # Tool buttons, pickers
│   └── CanvasFileCommands      # Menu commands
│
├── Canvas Library (to extract)
│   ├── Models/
│   │   ├── CanvasObject protocol
│   │   ├── AnyCanvasObject
│   │   ├── TextObject, ShapeObject, LineObject, ImageObject
│   │   ├── SelectionState, SelectionBox
│   │   └── Protocols (Fillable, Strokable, etc.)
│   ├── ViewModels/
│   │   └── CanvasViewModel
│   ├── Views/
│   │   ├── CanvasView
│   │   ├── CanvasObjectView (dispatcher)
│   │   ├── ShapeObjectView, TextObjectView, LineObjectView
│   │   ├── InfiniteGridView, MarqueeView
│   │   └── Selection/ (SelectionBoxView, ResizeHandle)
│   ├── Tools/
│   │   ├── CanvasTool protocol
│   │   ├── ToolRegistry
│   │   ├── ToolManifest
│   │   └── Built-in tools (SelectTool, ShapeTool, etc.)
│   └── Services/
│       └── ClipboardService
```

---

## Recommended Module Boundaries

### `AnnotationCanvas` (library target)

| Component | Visibility | Rationale |
|-----------|------------|-----------|
| `CanvasView` | Public | Main entry point for embedding |
| `CanvasViewModel` | Public | Required to drive CanvasView |
| `CanvasObject` protocol | Public | For custom object implementations |
| `ViewportState` | Public | For external viewport control |
| `ToolRegistry` | Public | For application to register tools |
| `CanvasTool` protocol | Public | For custom tool implementations |
| `DrawingTool` enum | Public | Tool identifiers |
| `SelectionState` | Public | For external selection query |
| Object models | Public | TextObject, ShapeObject, etc. |
| Tool implementations | Internal | SelectTool, ShapeTool, etc. |
| Gesture handling | Internal | Implementation detail |
| AppState | **Excluded** | Application-level only |

### `texttool` (application target)

| Component | Purpose |
|-----------|---------|
| `ToolbarView` | Application-specific tool UI |
| `HotkeyManager` | Keyboard shortcut handling |
| `AppState` | Export, file commands |
| `ContentView` | Compose toolbar + canvas |
| `ToolRegistry` configuration | Register tools + custom tools |

---

## Public API Surface

```swift
// Public API the app uses:
@StateObject var viewModel = CanvasViewModel()

CanvasView(viewModel: viewModel)

// Tool registration (application decides tools)
ToolRegistry.shared.register(SelectTool())
ToolRegistry.shared.register(ShapeTool.manifest(preset: .rectangle))

// Viewport control from app
viewModel.viewport.offset = CGPoint(x: 100, y: 100)
viewModel.viewport.scale = 2.0

// Listen to selection changes
viewModel.selectionState.$selectedIds
```

---

## Key Changes Required

1. **Create `AnnotationCanvas` framework target** with all core canvas code

2. **Add public access modifiers** to library APIs
   - Mark public: `CanvasView`, `CanvasViewModel`, `CanvasObject`, `ViewportState`, `ToolRegistry`, `CanvasTool`, `DrawingTool`, `SelectionState`, object models
   - Use `@MainActor` for public APIs interacting with ViewModel

3. **Remove AppKit dependencies** from library (move to app layer):
   - `AppState` → app layer
   - Keyboard monitoring in `CanvasView` → use callback or move to app
   - Cursor management → configurable via `CanvasView` modifiers

4. **ToolRegistry remains in library** but app configures it

5. **Extract toolbar to app** - it's application UI, not canvas core

6. **Hotkey handling at app layer** - keyboard shortcuts are app-specific

---

## Dependency Flow After Refactoring

```
┌─────────────────────────────────────────────────────┐
│                    texttool.app                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
│  │ ToolbarView │  │AppState     │  │Hotkeys     │  │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  │
│         │                │                │         │
│         └────────────────┼────────────────┘         │
│                          ▼                           │
│              ToolRegistry.shared                    │
│              (registers tools)                     │
└─────────────────────────┬───────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────┐
│                 AnnotationCanvas (library)           │
│  ┌───────────────────────────────────────────────┐  │
│  │              CanvasViewModel                  │  │
│  │  (all canvas state, object management)       │  │
│  └───────────────────────────────────────────────┘  │
│                          ▲                           │
│         ┌────────────────┴────────────────┐          │
│         ▼                                 ▼         │
│  ┌─────────────┐              ┌───────────────┐     │
│  │ CanvasView  │              │ ToolRegistry  │     │
│  │ (rendering) │              │ (tool impls)  │     │
│  └─────────────┘              └───────────────┘     │
│         ▲                                             
│         │                                             
│  ┌─────┴─────┐  ┌─────────┐  ┌──────────┐         
│  │ TextObject│  │ShapeObj │  │ LineObj  │         
│  └───────────┘  └─────────┘  └──────────┘         
└─────────────────────────────────────────────────────┘
```

---

## File Movement Plan

### Files to Move to `AnnotationCanvas` (library)

```
texttool/
├── Models/
│   ├── Protocols/
│   ├── AnyCanvasObject.swift
│   ├── TextObject.swift
│   ├── ShapeObject.swift
│   ├── LineObject.swift
│   ├── ImageObject.swift
│   ├── DrawingTool.swift
│   ├── SelectionState.swift
│   ├── SelectionBox.swift
│   ├── ViewportState.swift
│   └── ...
├── ViewModels/
│   └── CanvasViewModel.swift
├── Views/
│   ├── CanvasView.swift
│   ├── CanvasObjectView.swift
│   ├── ShapeObjectView.swift
│   ├── TextObjectView.swift
│   ├── LineObjectView.swift
│   ├── ImageObjectView.swift
│   ├── InfiniteGridView.swift
│   ├── MarqueeView.swift
│   ├── Selection/
│   ├── ScrollGestureModifier.swift
│   └── ...
├── Tools/
│   ├── CanvasTool.swift
│   ├── ToolRegistry.swift
│   ├── ToolManifest.swift
│   ├── SelectTool.swift
│   ├── HandTool.swift
│   ├── ShapeTool.swift
│   ├── LineTool.swift
│   ├── ArrowTool.swift
│   ├── TextTool.swift
│   └── ObjectViewRegistry.swift
└── Services/
    └── ClipboardService.swift
```

### Files Remaining in `texttool` (application)

```
texttool/
├── texttoolApp.swift          # App entry point
├── ContentView.swift          # Composes UI
├── AppState.swift             # Export, app commands
├── Views/
│   ├── ToolbarView.swift      # App toolbar
│   ├── FloatingFormatBar.swift
│   ├── ShapePickerView.swift
│   └── CanvasFileCommands.swift
└── (hotkey handling)
```

---

## Migration Steps

1. **Create new framework target** `AnnotationCanvas` in Xcode

2. **Move files** to the new target

3. **Add public access** modifiers:
   ```swift
   public struct CanvasView: View { ... }
   @MainActor public class CanvasViewModel: ObservableObject { ... }
   public protocol CanvasObject { ... }
   ```

4. **Create app target** that imports `AnnotationCanvas`

5. **Move app-specific code**:
   - `AppState` to app layer
   - Keyboard handling → app layer or callbacks
   - Toolbar components → app layer

6. **Update imports** in moved files:
   ```swift
   import AnnotationCanvas
   ```

7. **Test compilation** and fix access levels

---

## Considerations

### Why Not Include Toolbar in Library?

- Toolbar layout/buttons are application-specific
- Tool selection order varies by app
- Some apps may want different UI (floating palette, ribbon, etc.)
- Library provides `ToolRegistry` for apps to configure tools

### Why Keep Tool Implementations Internal?

- Tools depend on internal gesture handling
- Applications register tools via `ToolRegistry`, don't need internal APIs
- Allows internal refactoring without breaking public API

### Keyboard Handling

**Decision: App layer only (no keyboard handling in library)**

Keyboard shortcuts map to tool selection (`viewModel.selectedTool = .rectangle`) or command execution (`viewModel.deleteSelected()`), which are app-specific concerns. Different apps will want different keybindings, modifier keys, and command sets.

The library exposes the APIs that keyboard handlers call into — `CanvasViewModel` properties and methods, `ToolRegistry` — but has no opinion about how keys are mapped.

---

## Future Extensibility

Once extracted, the library enables:

- **Custom tools**: Apps can implement `CanvasTool` protocol
- **Custom objects**: Apps can implement `CanvasObject` protocol
- **Embedded canvas**: Use in settings panels, form builders, etc.
- **Cross-platform**: Foundation/SwiftUI core could be ported
