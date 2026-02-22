# Annota

A native macOS canvas drawing application built with SwiftUI, featuring an infinite canvas, multi-selection, pan/zoom, and comprehensive annotation tools. Built on **AnotarCanvas**, a reusable framework for canvas-based applications.

## Features

### Core Capabilities
- **Infinite Canvas** - Pan with trackpad gestures, zoom with pinch/controls
- **Multi-Selection** - Shift+click for additive selection, marquee drag-to-select
- **Selection Box** - Resize with corner/edge handles, rotate with Shift+snap (15°)
- **Viewport Controls** - Zoom slider, fit-to-content, reset view

### Drawing Tools
- **Text** - Click-to-place text with auto-growing input
- **Shapes** - Rectangle, Oval, Triangle, Diamond, Star (each is a separate tool)
- **Lines & Arrows** - Drag-to-create, Shift+constrain angles, configurable arrow heads
- **Text in Shapes** - All shapes support embedded text with auto-resize height

### Editing & Formatting
- **Rich Text** - Font size, bold, italic, color (via floating format bar)
- **Object Properties** - Fill color/opacity, stroke color/width/style
- **Clipboard** - Copy, paste, duplicate with smart offset
- **Keyboard Shortcuts** - Tool selection, delete, undo/redo

## Architecture

The project consists of two targets:

### **AnotarCanvas** (Reusable Framework)
A SwiftUI framework providing:
- **Plugin-based tool system** - Zero core modifications to add tools
- **Protocol-based object model** - `CanvasObject` protocol with type erasure (`AnyCanvasObject`)
- **Tool registry** - Dynamic tool registration with `ToolManifest`
- **Viewport system** - Pan/zoom with coordinate transformation
- **Selection system** - Multi-select with transform handles

### **Annota** (Application)
The macOS app built on AnotarCanvas:
- **Toolbar** - Tool buttons, shape picker, color controls
- **Hotkeys** - Keyboard shortcut management
- **Export** - Save canvas as PNG/PDF
- **UI/UX** - Icons, tooltips, application-specific features

### Key Design Patterns

**Plugin Architecture**: Each shape (Rectangle, Oval, etc.) is its own tool class inheriting from `BaseShapeTool`. Tools declare their identity via extensions to `DrawingTool`. No central enum to modify.

**Type Erasure**: All objects stored in `[AnyCanvasObject]` for heterogeneous storage. Type-safe retrieval via `.asType(_:)`.

**Capability Protocols**: Objects opt-in to capabilities via protocols (`TextContentObject`, `StrokableObject`, `FillableObject`).

**Tool-Agnostic Rendering**: `CanvasView` dispatches to tools via `ToolRegistry`. No hardcoded tool logic in the view layer.

## Getting Started

### Requirements

- macOS 13.0+
- Xcode 15.0+
- Swift 5.9+

### Build & Run

```bash
# Build framework
xcodebuild -scheme AnotarCanvas -configuration Debug build

# Build application
xcodebuild -scheme Annota -configuration Debug build

# Run all tests
xcodebuild test -scheme Annota

# Clean
xcodebuild -scheme Annota clean
```

## Documentation

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Overall system design and implementation phases
- **[CLAUDE.md](CLAUDE.md)** - Quick reference for AI assistants
- **[docs/AnotarCanvas-API.md](docs/AnotarCanvas-API.md)** - Complete framework API reference
- **[docs/adding-a-tool.md](docs/adding-a-tool.md)** - Step-by-step guide for adding custom tools

## Extending the Framework

### Adding a Custom Tool

```swift
// 1. Declare tool identity (in your tool file)
extension DrawingTool {
    public static let myTool = DrawingTool(id: "myTool")
}

// 2. Implement CanvasTool protocol
public struct MyTool: CanvasTool {
    public let toolType: DrawingTool = .myTool
    public var metadata: ToolMetadata { ... }

    // Override only the methods you need (all have defaults)
    public func handleDragEnded(...) { ... }
}

// 3. Register
ToolRegistry.shared.register(MyTool())
```

No modifications to framework core files required!

### Adding a Custom Object Type

```swift
// 1. Create object conforming to CopyableCanvasObject
public struct MyObject: CopyableCanvasObject { ... }

// 2. Create views (interactive + export)
struct MyObjectView: View { ... }

// 3. Create tool with ToolManifest
public struct MyTool: CanvasTool {
    static let manifest = ToolManifest(
        tool: MyTool(),
        discriminator: "myObject",
        interactiveView: { obj, sel, vm in AnyView(MyObjectView(...)) },
        exportView: { obj in AnyView(ExportMyObjectView(...)) }
    )
}

// 4. Register (one line registers tool, views, and clipboard support)
ToolRegistry.shared.register(MyTool.manifest)
```

See [docs/adding-a-tool.md](docs/adding-a-tool.md) for complete guide.

## Project Structure

```
texttool/
├── AnotarCanvas/              # Reusable framework
│   ├── Models/                # Object protocols, data models
│   ├── ViewModels/            # CanvasViewModel
│   ├── Views/                 # CanvasView, object views
│   ├── Tools/                 # Tool protocol, registry, built-in tools
│   │   └── Shapes/            # RectangleTool, OvalTool, etc.
│   └── Services/              # Clipboard, utilities
│
├── Annota/                    # macOS application
│   ├── Views/                 # ToolbarView, app-specific UI
│   ├── AppState.swift         # Export, file commands
│   └── AnnotaApp.swift        # App entry point
│
├── docs/                      # Documentation
│   ├── AnotarCanvas-API.md    # Framework API reference
│   └── adding-a-tool.md       # Tool development guide
│
└── AnnotaTests/               # Tests
```

## License

[Add your license here]

## Contributing

See [ARCHITECTURE.md](ARCHITECTURE.md) for design principles and contribution guidelines.
