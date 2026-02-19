# texttool

A native macOS canvas drawing application built with SwiftUI. Provides a FigJam-like interface for drawing text, rectangles, and circles on an infinite canvas with support for text inside shapes.

## Features

- **Drawing Tools** - Text, Rectangle, Circle with drag-to-create and real-time previews
- **Text in Shapes** - Rectangles and circles support embedded text with auto-resize height
- **Rich Text Formatting** - Floating format bar with font size, bold, italic, and color
- **Selection & Transform** - Single/multi-selection, resize with handles, rotation with Shift+snap (15°)
- **Infinite Canvas** - Pan and zoom with viewport controls
- **Keyboard Modifiers** - Shift+drag for proportional resize, Shift+rotate for angle snapping

## Getting Started

### Requirements

- macOS
- Xcode

### Build & Run

```bash
# Build
xcodebuild -scheme texttool -configuration Debug build

# Run tests
xcodebuild test -scheme texttool

# Clean
xcodebuild -scheme texttool clean
```

## Architecture

MVVM pattern with SwiftUI:

- **CanvasViewModel** - `@MainActor ObservableObject`, single source of truth for all canvas state
- **Data Models** - Structs (`TextObject`, `RectangleObject`, `CircleObject`) with hit testing
- **Views** - `ContentView` > `ToolbarView` + `CanvasView` with per-object views
- **Gestures** - Single `DragGesture` with distance check to distinguish clicks from drags

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed design documentation.
