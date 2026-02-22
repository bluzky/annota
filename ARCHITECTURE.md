# Annota Architecture

## Overview

**Annota** is a native macOS canvas drawing application built on **AnotarCanvas**, a reusable SwiftUI framework for canvas-based applications. The architecture follows a plugin-based design where tools and object types can be added without modifying core framework code.

## Table of Contents

1. [System Architecture](#system-architecture)
2. [AnotarCanvas Framework](#anotarcanvas-framework)
3. [Application Layer](#application-layer)
4. [Object Model](#object-model)
5. [Tool System](#tool-system)
6. [Selection System](#selection-system)
7. [Viewport System](#viewport-system)
8. [Gesture Handling](#gesture-handling)
9. [Extension Guide](#extension-guide)

---

## System Architecture

### Two-Target Structure

```
┌─────────────────────────────────────────────────────┐
│                   Annota (App)                       │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────┐  │
│  │ ToolbarView  │  │   AppState   │  │  Hotkeys  │  │
│  │  (UI layer)  │  │   (Export)   │  │(Shortcuts)│  │
│  └──────────────┘  └──────────────┘  └───────────┘  │
│                           │                          │
│                           ▼                          │
│              imports AnotarCanvas                   │
└─────────────────────────┬───────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────┐
│              AnotarCanvas (Framework)                │
│  ┌──────────────────────────────────────────────┐   │
│  │           CanvasViewModel                     │   │
│  │  • objects: [AnyCanvasObject]                │   │
│  │  • selectedTool: DrawingTool                 │   │
│  │  • selectionState: SelectionState            │   │
│  │  • viewport: ViewportState                   │   │
│  └──────────────────────────────────────────────┘   │
│          ▲                           ▲               │
│          │                           │               │
│  ┌───────┴─────────┐       ┌────────┴────────┐      │
│  │   CanvasView    │       │  ToolRegistry   │      │
│  │  (Rendering)    │       │  (Dispatch)     │      │
│  └─────────────────┘       └─────────────────┘      │
│          │                           │               │
│  ┌───────┴─────────┐       ┌────────┴────────┐      │
│  │ObjectViewReg    │       │   CanvasTool    │      │
│  │(View Factories) │       │   (Protocol)    │      │
│  └─────────────────┘       └─────────────────┘      │
│                                      │               │
│                         ┌────────────┴────────────┐  │
│                         ▼                         ▼ │
│              SelectTool  HandTool  TextTool       │
│              LineTool   ArrowTool                 │
│              RectangleTool  OvalTool  etc.        │
└──────────────────────────────────────────────────────┘
```

### Separation of Concerns

| Layer | Responsibility | Examples |
|-------|---------------|----------|
| **AnotarCanvas (Framework)** | Canvas behavior, object model, tool protocol, rendering | `CanvasView`, `CanvasViewModel`, `CanvasTool`, `CanvasObject` |
| **Annota (Application)** | UI/UX, keyboard shortcuts, icons, export, commands | `ToolbarView`, hotkeys, SF Symbol mapping, PNG export |

---

## AnotarCanvas Framework

### Core Components

#### CanvasViewModel

`@MainActor` class managing all canvas state:

```swift
@MainActor
public class CanvasViewModel: ObservableObject {
    @Published public var objects: [AnyCanvasObject]
    @Published public var selectedTool: DrawingTool
    @Published public var selectionState: SelectionState
    @Published public var viewport: ViewportState

    // Active properties (for new objects)
    @Published public var activeFillColor: Color?
    @Published public var activeStrokeColor: Color?
    @Published public var autoResizeShapes: Bool

    // Drag state (for preview rendering)
    public var dragStartPoint: CGPoint?
    public var currentDragPoint: CGPoint?
}
```

**Key Methods:**
- `addObject(_:)` - Add any `CanvasObject`
- `updateObject(_:)` - Update existing object
- `deleteObject(id:)` - Remove object
- `selectObject(at:)` - Hit test and select
- `copySelected()`, `paste()`, `duplicate()` - Clipboard operations

#### CanvasView

Main rendering view:

```swift
public struct CanvasView: View {
    @ObservedObject public var viewModel: CanvasViewModel
}
```

**Rendering Pipeline:**
1. Infinite grid background
2. All objects (sorted by zIndex)
3. Tool preview (via `ToolRegistry`)
4. Selection box overlay
5. Marquee selection overlay

**Gesture Handling:**
- Single `DragGesture` with `minimumDistance: 0`
- Distance < 5px = click, else = drag
- Delegates to tools via `ToolRegistry.tool(for:)`

---

## Object Model

### Protocol Hierarchy

```
CanvasObject (base protocol)
├── TextContentObject (adds text, textAttributes, isEditing)
├── StrokableObject (adds strokeColor, strokeWidth, strokeStyle)
├── FillableObject (adds fillColor, fillOpacity)
└── CopyableCanvasObject (adds Codable + copied(newId:zIndex:offset:))
```

### CanvasObject Protocol

```swift
public protocol CanvasObject: Identifiable {
    var id: UUID { get }
    var position: CGPoint { get set }
    var size: CGSize { get set }
    var rotation: CGFloat { get set }
    var isLocked: Bool { get set }
    var zIndex: Int { get set }

    func contains(_ point: CGPoint) -> Bool
    func boundingBox() -> CGRect
    func hitTest(_ point: CGPoint, threshold: CGFloat) -> HitTestResult?
}
```

**Default Implementations:**
- `boundingBox()` returns `CGRect(origin: position, size: size)`
- `hitTest(_:threshold:)` provides basic rectangular hit testing
- Rotation-aware `transformToLocal(_:)` and `transformToCanvas(_:)` helpers

**Capability Flags:**
```swift
var usesControlPoints: Bool { false }  // Override to true for line-like objects
```

### AnyCanvasObject (Type Erasure)

Enables heterogeneous storage while maintaining type safety:

```swift
public struct AnyCanvasObject: Identifiable {
    public let id: UUID
    public var base: any CanvasObject

    public init<T: CanvasObject>(_ object: T)

    // Type-safe casting
    public func asType<T: CanvasObject>(_ type: T.Type) -> T?
}
```

**Usage:**
```swift
let rect = ShapeObject(...)
let anyRect = AnyCanvasObject(rect)
viewModel.addObject(anyRect)

// Retrieve
if let shape = anyRect.asType(ShapeObject.self) {
    print(shape.svgPath)
}
```

### Built-in Object Types

#### ShapeObject (Rectangle, Oval, Triangle, Diamond, Star)

```swift
public struct ShapeObject: CanvasObject, FillableObject, StrokableObject, TextContentObject {
    public var svgPath: String      // "M 0,0 L 100,0 L 100,100 L 0,100 Z"
    public var toolId: String        // "rectangle", "oval", etc.

    // FillableObject
    public var fillColor: Color
    public var fillOpacity: Double

    // StrokableObject
    public var strokeColor: Color
    public var strokeWidth: CGFloat
    public var strokeStyle: StrokeStyle

    // TextContentObject
    public var text: String
    public var textAttributes: TextAttributes
    public var isEditing: Bool
    public var autoResizeHeight: Bool

    // CanvasObject base
    public let id: UUID
    public var position: CGPoint
    public var size: CGSize
    public var rotation: CGFloat
    public var isLocked: Bool
    public var zIndex: Int
}
```

**Rendering:** `ShapeObjectView` parses `svgPath` with `SVGPath.parse()` and scales to object size.

#### TextObject

```swift
public struct TextObject: CanvasObject, TextContentObject {
    public var text: String
    public var textAttributes: TextAttributes
    public var isEditing: Bool

    // CanvasObject base
    // ...
}
```

#### LineObject & ArrowObject

```swift
public struct LineObject: CanvasObject, StrokableObject {
    public var startPoint: CGPoint
    public var endPoint: CGPoint
    public var label: String
    public var isEditingLabel: Bool

    // Computed
    public var position: CGPoint { /* min of start/end */ }
    public var size: CGSize { /* abs diff of start/end */ }

    public var usesControlPoints: Bool { true }
}

public struct ArrowObject: CanvasObject, StrokableObject {
    public var startPoint: CGPoint
    public var endPoint: CGPoint
    public var startArrowHead: ArrowHead
    public var endArrowHead: ArrowHead
    // ...
}
```

**Lines use control points instead of selection box** - `usesControlPoints` flag changes rendering.

#### ImageObject

```swift
public struct ImageObject: CanvasObject {
    public var imageData: Data?
    public var aspectRatio: CGFloat
    public var maintainAspectRatio: Bool
    // ...
}
```

---

## Tool System

### Plugin Architecture

**Zero core modifications** to add tools. Tools declare their identity inline.

#### DrawingTool (Identity)

Lightweight value type:

```swift
public struct DrawingTool: Hashable {
    public let id: String
    public init(id: String)
}
```

**Tool identities declared per-file via extensions:**

```swift
// In SelectTool.swift
extension DrawingTool {
    public static let select = DrawingTool(id: "select")
}

// In RectangleTool.swift
extension DrawingTool {
    public static let rectangle = DrawingTool(id: "rectangle")
}
```

**No central enum to modify.**

#### CanvasTool Protocol

```swift
public protocol CanvasTool {
    var toolType: DrawingTool { get }
    var metadata: ToolMetadata { get }

    // All methods have default no-op implementations
    func handleDragChanged(start: CGPoint, current: CGPoint, viewModel: CanvasViewModel)
    func handleDragEnded(start: CGPoint, end: CGPoint, viewModel: CanvasViewModel, shiftHeld: Bool)
    func handleClick(at: CGPoint, viewModel: CanvasViewModel, shiftHeld: Bool)
    func renderPreview(start: CGPoint, current: CGPoint, viewModel: CanvasViewModel) -> AnyView
}
```

**Override only what you need** - all have default no-op implementations.

#### ToolMetadata

```swift
public struct ToolMetadata {
    public let name: String
    public let category: ToolCategory
    public let cursorType: NSCursor
}

public enum ToolCategory {
    case selection      // Select, Hand
    case shape          // Rectangle, Oval, etc.
    case drawing        // Line, Arrow
    case annotation     // Text, Note
    case navigation     // Hand, Zoom
}
```

**Framework concerns only** - no icons or keyboard shortcuts (those are app-specific).

#### ToolRegistry

Singleton managing tool registration:

```swift
@MainActor
public class ToolRegistry: ObservableObject {
    public static let shared: ToolRegistry

    // Register tool (no new object type)
    public func register(_ tool: any CanvasTool)

    // Register tool with new object type (auto-registers views + codable)
    public func register<Obj: CopyableCanvasObject>(_ manifest: ToolManifest<Obj>)

    // Retrieve
    public func tool(for type: DrawingTool) -> (any CanvasTool)?
    public func tools(in category: ToolCategory) -> [any CanvasTool]
}
```

**Built-in registrations:**
```swift
ToolRegistry.shared.register(SelectTool())
ToolRegistry.shared.register(HandTool())
ToolRegistry.shared.register(TextTool.manifest)
ToolRegistry.shared.register(LineTool())
ToolRegistry.shared.register(ArrowTool())
ToolRegistry.shared.register(RectangleTool())
ToolRegistry.shared.register(OvalTool())
// etc.
```

#### ToolManifest (New Object Types)

Bundles tool + views + codable discriminator:

```swift
public struct ToolManifest<Obj: CopyableCanvasObject> {
    public let tool: any CanvasTool
    public let discriminator: String
    public let interactiveView: (Obj, Bool, CanvasViewModel) -> AnyView
    public let exportView: (Obj) -> AnyView
}
```

**Usage:**
```swift
// In StickerTool.swift
static let manifest = ToolManifest(
    tool: StickerTool(),
    discriminator: "sticker",
    interactiveView: { obj, sel, vm in AnyView(StickerObjectView(...)) },
    exportView: { obj in AnyView(ExportStickerObjectView(...)) }
)

// Register
ToolRegistry.shared.register(StickerTool.manifest)
```

**One call registers:**
- Tool in `ToolRegistry`
- Interactive view in `ObjectViewRegistry`
- Export view in `ObjectViewRegistry`
- Codable discriminator in `CodableObjectRegistry`

### Shape Tools Architecture

**Each shape is its own tool class:**

```
BaseShapeTool (abstract base class)
├── RectangleTool
├── OvalTool
├── TriangleTool
├── DiamondTool
└── StarTool
```

**BaseShapeTool** provides shared drag-to-create logic:

```swift
open class BaseShapeTool: CanvasTool {
    open var svgPath: String { fatalError("Override") }
    open var toolType: DrawingTool { fatalError("Override") }
    open var metadata: ToolMetadata { fatalError("Override") }

    // Shared implementation
    public func handleDragChanged(start: CGPoint, current: CGPoint, viewModel: CanvasViewModel) {
        // Calculate size, position
        // Create or update ShapeObject with svgPath
    }
}
```

**Concrete shape tools:**

```swift
// RectangleTool.swift
extension DrawingTool {
    public static let rectangle = DrawingTool(id: "rectangle")
}

public class RectangleTool: BaseShapeTool {
    public override var metadata: ToolMetadata {
        ToolMetadata(name: "Rectangle", category: .shape)
    }

    public override var toolType: DrawingTool { .rectangle }

    public override var svgPath: String {
        "M 0,0 L 100,0 L 100,100 L 0,100 Z"
    }
}
```

**ShapeObject stores path directly:**
```swift
let shape = ShapeObject(
    svgPath: "M 0,0 L 100,0 ...",  // Geometry
    toolId: "rectangle",            // For deserialization
    ...
)
```

**No intermediate enum** - tools define paths inline.

---

## Selection System

### SelectionState

```swift
public struct SelectionState {
    public var selectedIds: Set<UUID>
    public var editingId: UUID?

    public var isEmpty: Bool
    public var count: Int
    public var isSingleSelection: Bool
    public var isMultiSelection: Bool

    public mutating func select(_ id: UUID, additive: Bool)
    public mutating func selectMultiple(_ ids: Set<UUID>)
    public mutating func deselectAll()
    public mutating func startEditing(_ id: UUID)
}
```

### SelectionBox

Computed from selected objects:

```swift
public struct SelectionBox {
    public let bounds: CGRect
    public let individualBounds: [UUID: CGRect]
    public let center: CGPoint
    public let rotation: CGFloat  // Only for single selection

    public func hitTest(_ point: CGPoint) -> SelectionHitZone?
}

public enum SelectionHitZone {
    case move
    case corner(Corner)     // Resize
    case edge(Edge)         // Resize
    case rotation(Corner)   // Rotate (outside corners)
}
```

**Selection box rendering:**
- Corners: 8x8 handles for resize
- Edges: Invisible hit zones for edge resize
- Outside corners: Rotation handles with circular icon
- Interior: Move cursor

**Multi-selection:**
- Shift+click for additive selection
- Marquee drag (empty canvas) for rect selection
- All selected objects resize proportionally from center

---

## Viewport System

### ViewportState

```swift
public struct ViewportState {
    public var offset: CGPoint      // Pan offset
    public var scale: CGFloat       // Zoom level (1.0 = 100%)

    public let minScale: CGFloat = 0.1
    public let maxScale: CGFloat = 10.0

    // Coordinate conversion
    public func canvasPoint(from screenPoint: CGPoint) -> CGPoint
    public func screenPoint(from canvasPoint: CGPoint) -> CGPoint

    // Transformations
    public mutating func zoom(by factor: CGFloat, centeredOn point: CGPoint)
    public mutating func pan(by delta: CGPoint)
    public mutating func reset()
    public mutating func fitContent(_ bounds: CGRect, in viewSize: CGSize)
}
```

**Rendering transform:**
```swift
ZStack {
    // Objects layer
    ForEach(viewModel.objects) { obj in
        ObjectView(obj)
    }
}
.scaleEffect(viewport.scale, anchor: .topLeading)
.offset(x: viewport.offset.x, y: viewport.offset.y)
```

**Gesture handling:**
- Two-finger trackpad drag: pan
- Pinch gesture: zoom centered on pinch center
- Hand tool + single drag: pan

---

## Gesture Handling

### Interaction State Machine

```swift
enum InteractionMode {
    case idle
    case dragging(DragContext)
    case drawing(DrawingContext)
    case selecting(MarqueeContext)
    case panning
    case editing(UUID)
}
```

### Gesture Flow

1. **DragGesture starts** (`onChanged` first call)
   - Check active tool
   - If `.select`: hit test selection box handles, then objects
   - If drawing tool: delegate to tool's `handleDragChanged`
   - Store initial state in `DragContext` or `DrawingContext`

2. **DragGesture updates** (`onChanged` subsequent calls)
   - Update `currentDragPoint` on viewModel
   - Tool renders preview via `renderPreview(start:current:viewModel:)`
   - Selection box updates if resizing/rotating

3. **DragGesture ends** (`onEnded`)
   - Calculate distance: `hypot(translation.width, translation.height)`
   - If distance < 5px → **click** → delegate to tool's `handleClick`
   - Else → **drag** → delegate to tool's `handleDragEnded`
   - Reset drag state

### Tool Dispatch

**CanvasView** delegates to tools via registry:

```swift
private func handleDragEnded(_ value: DragGesture.Value) {
    let distance = hypot(value.translation.width, value.translation.height)
    let canvasLocation = viewModel.viewport.canvasPoint(from: value.location)

    if distance < 5 {
        // Click
        if let tool = ToolRegistry.shared.tool(for: viewModel.selectedTool) {
            tool.handleClick(at: canvasLocation, viewModel: viewModel, shiftHeld: shiftHeld)
        }
    } else {
        // Drag
        if let tool = ToolRegistry.shared.tool(for: viewModel.selectedTool) {
            tool.handleDragEnded(start: canvasStart, end: canvasLocation, viewModel: viewModel, shiftHeld: shiftHeld)
        }
    }
}
```

**No hardcoded tool logic in CanvasView.**

---

## Extension Guide

### Adding a Custom Tool (Existing Object Type)

**Example:** A "Pencil" tool that creates `LineObject`

```swift
// PencilTool.swift (in your application or plugin)

import AnotarCanvas

// 1. Declare tool identity
extension DrawingTool {
    public static let pencil = DrawingTool(id: "pencil")
}

// 2. Implement CanvasTool
public struct PencilTool: CanvasTool {
    public let toolType: DrawingTool = .pencil

    public var metadata: ToolMetadata {
        ToolMetadata(name: "Pencil", category: .drawing)
    }

    // 3. Override only needed methods
    public func handleDragEnded(
        start: CGPoint,
        end: CGPoint,
        viewModel: CanvasViewModel,
        shiftHeld: Bool
    ) {
        let line = LineObject(startPoint: start, endPoint: end, strokeColor: viewModel.activeStrokeColor ?? .black)
        viewModel.addObject(line)
    }
}

// 4. Register
ToolRegistry.shared.register(PencilTool())
```

**Files modified:** Zero framework files. Just add `PencilTool.swift`.

### Adding a Custom Object Type

**Example:** A "Sticker" tool with `StickerObject`

```swift
// 1. Object model
public struct StickerObject: CopyableCanvasObject {
    public let id: UUID
    public var position: CGPoint
    public var size: CGSize
    public var rotation: CGFloat = 0
    public var isLocked: Bool = false
    public var zIndex: Int = 0

    public var emoji: String

    public func contains(_ point: CGPoint) -> Bool { ... }
    public func boundingBox() -> CGRect { ... }

    public func copied(newId: UUID, zIndex: Int, offset: CGPoint) -> StickerObject {
        StickerObject(id: newId, position: position + offset, emoji: emoji, ...)
    }
}

// 2. Interactive view
struct StickerObjectView: View {
    let object: StickerObject
    let isSelected: Bool
    @ObservedObject var viewModel: CanvasViewModel

    var body: some View {
        Text(object.emoji)
            .font(.system(size: 40))
            .position(...)
    }
}

// 3. Export view (can reuse StickerObjectView for simple cases)

// 4. Tool with manifest
extension DrawingTool {
    public static let sticker = DrawingTool(id: "sticker")
}

public struct StickerTool: CanvasTool {
    public let toolType: DrawingTool = .sticker
    public var metadata: ToolMetadata { ... }

    public func handleClick(at point: CGPoint, viewModel: CanvasViewModel, shiftHeld: Bool) {
        let sticker = StickerObject(position: point, emoji: "⭐️")
        viewModel.addObject(sticker)
    }

    public static let manifest = ToolManifest(
        tool: StickerTool(),
        discriminator: "sticker",
        interactiveView: { obj, sel, vm in AnyView(StickerObjectView(object: obj, isSelected: sel, viewModel: vm)) },
        exportView: { obj in AnyView(ExportStickerObjectView(object: obj)) }
    )
}

// 5. Register (one call registers tool + views + clipboard)
ToolRegistry.shared.register(StickerTool.manifest)
```

**Files modified:** Zero framework files. Add `StickerObject.swift`, `StickerObjectView.swift`, `StickerTool.swift`.

See [docs/adding-a-tool.md](docs/adding-a-tool.md) for complete guide.

---

## Application Layer (Annota)

### ToolbarView

Application-specific UI for tool selection:

- **Tool buttons** with icons (SF Symbols)
- **Shape picker** popover (maps DrawingTool → icon)
- **Color pickers** for fill/stroke
- **Viewport controls** (zoom slider, fit, reset)

**Icon mapping (app concern):**
```swift
let shapeIcons: [DrawingTool: String] = [
    .rectangle: "rectangle",
    .oval: "circle",
    .triangle: "triangle",
    .diamond: "diamond",
    .star: "star",
]
```

### Keyboard Shortcuts (app concern)

```swift
// HotkeyManager.swift
class HotkeyManager {
    func installHotkeys(viewModel: CanvasViewModel) {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.charactersIgnoringModifiers {
            case "v": viewModel.selectedTool = .select
            case "h": viewModel.selectedTool = .hand
            case "t": viewModel.selectedTool = .text
            case "r": viewModel.selectedTool = .rectangle
            // ...
            }
        }
    }
}
```

**Framework has no keyboard handling** - app controls all shortcuts.

### Export (app concern)

```swift
// AppState.swift
func exportToPNG() {
    let exportView = CanvasExportView(objects: viewModel.objects)
    let renderer = ImageRenderer(content: exportView)
    // ...
}
```

---

## Design Principles

### 1. Zero Core Modifications for Extensions

Adding a tool or object type **requires zero modifications to framework files**:
- ✅ No changes to `DrawingTool.swift` (identities declared per-file)
- ✅ No changes to `CanvasView.swift` (dispatches via registry)
- ✅ No changes to `CanvasViewModel.swift` (generic `addObject(_:)`)
- ✅ No changes to `CanvasObjectView.swift` (uses `ObjectViewRegistry`)

### 2. Protocol-Based Capabilities

Objects opt-in to capabilities via protocols:
- `TextContentObject` → text editing
- `StrokableObject` → stroke styling
- `FillableObject` → fill styling
- `CopyableCanvasObject` → clipboard support

### 3. Type Safety with Type Erasure

- All objects stored in `[AnyCanvasObject]` (heterogeneous)
- Type-safe retrieval via `.asType(_:)` (no force casting)
- Protocol-based dispatch where possible

### 4. Tool-Agnostic Rendering

`CanvasView` has **zero hardcoded tool logic**:
- Preview rendering: `tool.renderPreview()`
- Gesture handling: `tool.handleDragChanged()` / `tool.handleDragEnded()`
- Object rendering: `ObjectViewRegistry`

### 5. Separation of Framework and Application

| Concern | Layer |
|---------|-------|
| Canvas behavior | Framework |
| Tool protocol | Framework |
| Object model | Framework |
| Icons | Application |
| Keyboard shortcuts | Application |
| Export formats | Application |
| Toolbar UI | Application |

---

## Implementation Status

### ✅ Completed (Production)

**Phase 1: Foundation**
- Unified object system with `CanvasObject` protocol
- Type-erased `AnyCanvasObject` wrapper
- Multi-selection with Shift+click
- Marquee drag-to-select
- Viewport pan/zoom system
- Tool-agnostic `CanvasView`

**Phase 2: Selection Box Interactions**
- Corner/edge resize handles
- Rotation handles (outside corners)
- Cursor feedback
- Multi-object resize

**Phase 3: Tool Plugin Architecture**
- `CanvasTool` protocol with default implementations
- `ToolRegistry` with dynamic registration
- `ToolManifest` for new object types
- Framework extraction as `AnotarCanvas`

**Phase 4: Shape Tool Refactor**
- Each shape is its own tool (RectangleTool, OvalTool, etc.)
- `BaseShapeTool` provides shared logic
- `ShapeObject` stores SVG path directly (no preset enum)
- Icons/shortcuts moved to application layer

**Phase 5: Built-in Tools**
- SelectTool, HandTool
- TextTool with auto-growing input
- LineTool, ArrowTool with angle snapping
- RectangleTool, OvalTool, TriangleTool, DiamondTool, StarTool

**Phase 6: Clipboard & Persistence**
- Copy/paste/duplicate
- `CodableCanvasObject` with discriminator registry
- PNG/PDF export (application layer)

### 🚧 Potential Future Enhancements

- Undo/redo system (action-based history)
- Pencil/highlighter tools (freehand drawing)
- Auto-number tool (numbered annotations)
- Note tool (sticky notes)
- Image paste support
- Arrow binding (optional connect-to-shape feature)
- Keyboard command recording/playback
- Plugin API for third-party tools

---

## File Structure

```
texttool/
├── AnotarCanvas/                      # Framework
│   ├── Models/
│   │   ├── Protocols/
│   │   │   ├── CanvasObject.swift
│   │   │   ├── CanvasTool.swift
│   │   │   ├── TextContentObject.swift
│   │   │   ├── StrokableObject.swift
│   │   │   └── FillableObject.swift
│   │   ├── AnyCanvasObject.swift
│   │   ├── DrawingTool.swift          # Lightweight struct
│   │   ├── TextObject.swift
│   │   ├── ShapeObject.swift
│   │   ├── LineObject.swift
│   │   ├── ArrowObject.swift
│   │   ├── ImageObject.swift
│   │   ├── SelectionState.swift
│   │   ├── SelectionBox.swift
│   │   ├── ViewportState.swift
│   │   └── CodableCanvasObject.swift
│   │
│   ├── ViewModels/
│   │   └── CanvasViewModel.swift
│   │
│   ├── Views/
│   │   ├── CanvasView.swift           # Tool-agnostic rendering
│   │   ├── CanvasObjectView.swift     # Dispatcher
│   │   ├── ShapeObjectView.swift
│   │   ├── TextObjectView.swift
│   │   ├── LineObjectView.swift
│   │   ├── ArrowObjectView.swift
│   │   ├── ImageObjectView.swift
│   │   ├── InfiniteGridView.swift
│   │   ├── MarqueeView.swift
│   │   ├── Selection/
│   │   │   ├── SelectionBoxView.swift
│   │   │   └── ResizeHandle.swift
│   │   └── CanvasExportView.swift
│   │
│   ├── Tools/
│   │   ├── ToolRegistry.swift
│   │   ├── ToolManifest.swift
│   │   ├── ObjectViewRegistry.swift
│   │   ├── SelectTool.swift
│   │   ├── HandTool.swift
│   │   ├── TextTool.swift
│   │   ├── LineTool.swift
│   │   ├── ArrowTool.swift
│   │   └── Shapes/
│   │       ├── BaseShapeTool.swift
│   │       ├── RectangleTool.swift
│   │       ├── OvalTool.swift
│   │       ├── TriangleTool.swift
│   │       ├── DiamondTool.swift
│   │       └── StarTool.swift
│   │
│   └── Services/
│       └── ClipboardService.swift
│
├── Annota/                            # Application
│   ├── AnnotaApp.swift
│   ├── ContentView.swift
│   ├── AppState.swift
│   ├── Views/
│   │   ├── ToolbarView.swift
│   │   ├── ShapePickerView.swift
│   │   ├── FloatingFormatBar.swift
│   │   └── CanvasFileCommands.swift
│   └── Assets.xcassets/
│
├── docs/
│   ├── AnotarCanvas-API.md            # Framework API reference
│   ├── adding-a-tool.md               # Extension guide
│   └── archive/                       # Implemented proposals
│
├── ARCHITECTURE.md                    # This file
├── CLAUDE.md                          # Quick reference
└── README.md                          # Project overview
```

---

## References

- **[docs/AnotarCanvas-API.md](docs/AnotarCanvas-API.md)** - Complete framework API documentation
- **[docs/adding-a-tool.md](docs/adding-a-tool.md)** - Step-by-step extension guide
- **[CLAUDE.md](CLAUDE.md)** - Quick reference for AI assistants
- **[README.md](README.md)** - Project overview and getting started
