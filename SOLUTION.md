# Text Tool Canvas Application - Architecture Overview

## Current Architecture (Phase 1 Complete)

This macOS SwiftUI application provides a FigJam-like canvas for drawing text, rectangles, and circles with support for text inside shapes.

---

## Protocol-Based Object Model

All canvas objects now conform to a unified protocol hierarchy:

### Core Protocols (`Models/Protocols/`)

| Protocol | Purpose |
|----------|---------|
| `CanvasObject` | Base protocol with id, position, size, rotation, isLocked, zIndex, hit testing |
| `TextContentObject` | For objects containing text (text, textAttributes, isEditing) |
| `StrokableObject` | For objects with strokes (strokeColor, strokeWidth, strokeStyle) |
| `FillableObject` | For objects with fills (fillColor, fillOpacity) |

### Supporting Types (`Models/`)

| Type | Purpose |
|------|---------|
| `StrokeStyleType` | Enum: solid, dashed(pattern), dotted |
| `TextAttributes` | Font family, size, weight, italic, color, alignment |
| `HitTestResult` | Enum: body, edge, corner, rotationHandle, controlPoint, label |
| `Corner` / `Edge` | Enums for selection box handles |
| `CodableColor` | Wrapper for persisting SwiftUI Color |
| `AnyCanvasObject` | Type-erased wrapper for heterogeneous collections |

---

## Data Models

### TextObject
- Conforms to: `CanvasObject`, `TextContentObject`
- Properties: position, size, rotation, isLocked, zIndex, text, textAttributes, isEditing
- Backward-compatible: `fontSize` and `color` computed properties

### RectangleObject
- Conforms to: `CanvasObject`, `TextContentObject`, `StrokableObject`, `FillableObject`
- Properties: All base properties plus strokeColor, strokeWidth, strokeStyle, fillColor, fillOpacity, cornerRadius, autoResizeHeight
- Backward-compatible: `color` computed property maps to strokeColor/fillColor

### CircleObject
- Conforms to: `CanvasObject`, `TextContentObject`, `StrokableObject`, `FillableObject`
- Same properties as RectangleObject
- Hit testing uses ellipse equation: `((x-cx)/rx)² + ((y-cy)/ry)² ≤ 1`

---

## State Management

### CanvasViewModel (`ViewModels/CanvasViewModel.swift`)

Single source of truth for all canvas state:

```
@MainActor class CanvasViewModel: ObservableObject
├── Object Storage
│   ├── textObjects: [TextObject]
│   ├── rectangleObjects: [RectangleObject]
│   └── circleObjects: [CircleObject]
│
├── Tool State
│   ├── selectedTool: DrawingTool (.select, .text, .rectangle, .circle)
│   ├── selectedObjectId: UUID?
│   ├── activeTextSize: CGFloat
│   ├── activeColor: Color
│   └── autoResizeShapes: Bool
│
└── Transient Drag State
    ├── dragStartPoint: CGPoint?
    └── currentDragPoint: CGPoint?
```

### Key Methods

| Method | Purpose |
|--------|---------|
| `addTextObject(at:)` | Creates text object, returns UUID |
| `addRectangle(from:to:)` | Creates rectangle from drag bounds |
| `addCircle(from:to:)` | Creates ellipse from drag bounds |
| `selectObject(at:)` | Hit tests in z-order (text → circles → rectangles) |
| `startEditing(objectId:)` | Enables text editing mode |
| `updateText(objectId:text:)` | Updates text across all object types |
| `deselectAll()` | Exits editing, clears selection |
| `moveTextObject/Rectangle/Circle(id:by:)` | Translates objects by offset |

---

## View Hierarchy

```
ContentView
├── VStack
│   ├── ToolbarView
│   │   ├── Tool Picker (Select, Text, Rectangle, Circle)
│   │   ├── Font Size Picker
│   │   ├── Color Picker
│   │   └── Auto-resize Toggle
│   │
│   └── CanvasView
│       └── GeometryReader → ZStack
│           ├── Background (gray #d8d8d8)
│           ├── Dot Grid (20pt spacing)
│           ├── RectangleObjectView (ForEach)
│           ├── CircleObjectView (ForEach)
│           ├── TextObjectView (ForEach)
│           ├── Rectangle drag preview
│           └── Circle drag preview
```

---

## Gesture Handling

### DragGesture (minimumDistance: 0)

The canvas uses a single DragGesture that distinguishes clicks from drags:

```
onChanged:
  - Rectangle/Circle tools: Track drag start/current for preview
  - Select tool: Move selected object by offset delta

onEnded:
  - distance < 5px → handleClick()
  - distance ≥ 5px → Create shape (rectangle/circle tools)
```

### Click Handling

| Tool | Click Behavior |
|------|---------------|
| Text | Click object → edit; Click empty while editing → commit; Click empty → create new |
| Select | Single click → select; Double click → edit; Click empty → deselect |
| Rectangle/Circle | Click does nothing (drag to create) |

### Double-Click Detection

- Time threshold: 0.3 seconds
- Distance threshold: 10 points
- Tracks `lastTapTime` and `lastTapLocation`

---

## Object Views

### TextObjectView
- Editing mode: `AutoGrowingTextView` (NSTextView wrapper, grows horizontally)
- View mode: Static `Text` with selection outline

### RectangleObjectView / CircleObjectView
- Shape stroke with active color (opacity 0.1 fill)
- Editing mode: `ConstrainedAutoGrowingTextView` (fixed width, grows vertically)
- View mode: Centered multiline text
- Auto-resize: Computes text height with AppKit font metrics, updates object height

### AutoGrowingTextView (`Views/AutoGrowingTextView.swift`)
- `NSViewRepresentable` wrapping `NSTextView`
- Two variants:
  - `AutoGrowingTextView`: Unlimited horizontal growth (for standalone text)
  - `ConstrainedAutoGrowingTextView`: Fixed width with height callback (for shapes)

---

## Coordinate System

- **Origin**: Top-left corner (SwiftUI natural)
- **Position**: Stored as CGPoint representing top-left of bounding box
- **Rendering**: Uses `.position()` modifier (centers at position + size/2)
- **Hit Testing**: All calculations in absolute canvas coordinates

---

## Z-Order

**Rendering Order** (bottom to top):
1. Background
2. Dot grid
3. Rectangles
4. Circles
5. Text objects
6. Drag previews

**Hit Testing Order** (top to bottom):
1. Text objects (reversed)
2. Circle objects (reversed)
3. Rectangle objects (reversed)

---

## Future Architecture (Planned)

### Phase 1.3+: Unified Object Storage
- Replace separate arrays with `objects: [AnyCanvasObject]`
- Z-ordering via `zIndex` property

### Phase 1.4: Multi-Selection
- `selectedIds: Set<UUID>` for multiple selection
- Shift+Click for additive selection
- Marquee drag-to-select

### Phase 1.5: Viewport
- Pan/zoom with `ViewportState`
- Two-finger trackpad gestures
- Hand tool for panning

### Phase 2: Selection Box
- Resize handles on corners/edges
- Rotation handles outside corners
- Cursor feedback system

### Phase 3+: Additional Tools
- Line, Arrow, Pencil, Highlighter
- Auto-Number, Mosaic, Note, Sticker, Image

See `ARCHITECTURE.md` for complete implementation plan.
