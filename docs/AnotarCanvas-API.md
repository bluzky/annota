# AnotarCanvas API Documentation

## Overview

**AnotarCanvas** is a reusable SwiftUI framework for building canvas-based drawing and annotation applications. It provides an infinite canvas with pan/zoom, multi-selection, drag-to-create tools, and a plugin-based architecture for custom tools and objects.

**Key Features:**
- Infinite canvas with pan/zoom viewport
- Multi-selection with resize/rotate handles
- Plugin-based tool system (zero core modifications to add tools)
- Protocol-based object model with type erasure
- Built-in tools: Select, Hand, Text, Line, Arrow, Shapes (Rectangle, Oval, Triangle, Diamond, Star)
- Clipboard support with custom object types

---

## Public API

### Core Components

#### CanvasView

The main entry point for embedding a canvas in your application.

```swift
public struct CanvasView: View {
    @ObservedObject public var viewModel: CanvasViewModel

    public init(viewModel: CanvasViewModel)
}
```

**Usage:**
```swift
@StateObject private var viewModel = CanvasViewModel()

var body: some View {
    CanvasView(viewModel: viewModel)
}
```

---

#### CanvasViewModel

The view model managing all canvas state. Must be created on the `@MainActor`.

```swift
@MainActor
public class CanvasViewModel: ObservableObject
```

**Key Published Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `objects` | `[AnyCanvasObject]` | All canvas objects (heterogeneous) |
| `selectedTool` | `DrawingTool` | Currently active tool |
| `selectionState` | `SelectionState` | Selection state (selected IDs, editing ID) |
| `viewport` | `ViewportState` | Pan/zoom state |
| `activeFillColor` | `Color?` | Active fill color for new objects |
| `activeStrokeColor` | `Color?` | Active stroke color for new objects |
| `autoResizeShapes` | `Bool` | Auto-resize shape height for text |

**Key Methods:**

```swift
// Object management
func addObject(_ object: any CanvasObject)
func updateObject(_ updated: AnyCanvasObject)
func deleteObject(id: UUID)
func deleteSelected()

// Selection
func selectObject(at point: CGPoint) -> UUID?
func selectObjects(ids: Set<UUID>)
func deselectAll()
func startEditing(objectId: UUID)

// Clipboard
func copySelected()
func paste()
func duplicate()

// Viewport
func resetViewport()
func fitToContent()
```

---

### Object Model

#### CanvasObject Protocol

Base protocol for all canvas objects.

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
- `boundingBox()` - Returns `CGRect(origin: position, size: size)`
- `hitTest(_:threshold:)` - Basic rectangular hit testing

**Capability Flags:**
```swift
var usesControlPoints: Bool { false }  // Override to true for objects like lines
```

---

#### Capability Protocols

**TextContentObject** - Objects with editable text:
```swift
public protocol TextContentObject: CanvasObject {
    var text: String { get set }
    var textAttributes: TextAttributes { get set }
    var isEditing: Bool { get set }
}
```

**StrokableObject** - Objects with stroke/border:
```swift
public protocol StrokableObject: CanvasObject {
    var strokeColor: Color { get set }
    var strokeWidth: CGFloat { get set }
    var strokeStyle: StrokeStyle { get set }
}
```

**FillableObject** - Objects with fill:
```swift
public protocol FillableObject: CanvasObject {
    var fillColor: Color { get set }
    var fillOpacity: Double { get set }
}
```

**CopyableCanvasObject** - Objects supporting clipboard operations:
```swift
public protocol CopyableCanvasObject: CanvasObject, Codable {
    func copied(newId: UUID, zIndex: Int, offset: CGPoint) -> Self
}
```

---

#### AnyCanvasObject

Type-erased wrapper for heterogeneous object storage.

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
let rect = ShapeObject(position: .zero, size: CGSize(width: 100, height: 100), ...)
let anyObj = AnyCanvasObject(rect)
viewModel.addObject(anyObj)

// Type-safe retrieval
if let shape = anyObj.asType(ShapeObject.self) {
    print(shape.svgPath)
}
```

---

#### Built-in Object Types

**TextObject**
```swift
public struct TextObject: CanvasObject, TextContentObject {
    public var text: String
    public var textAttributes: TextAttributes
    // ... CanvasObject properties
}
```

**ShapeObject** (Rectangle, Oval, Triangle, Diamond, Star)
```swift
public struct ShapeObject: CanvasObject, FillableObject, StrokableObject, TextContentObject {
    public var svgPath: String      // SVG path geometry
    public var toolId: String        // "rectangle", "oval", etc.
    public var fillColor: Color
    public var strokeColor: Color
    public var text: String
    // ... CanvasObject properties
}
```

**LineObject**
```swift
public struct LineObject: CanvasObject, StrokableObject {
    public var startPoint: CGPoint
    public var endPoint: CGPoint
    public var label: String
    // ... CanvasObject properties

    public var usesControlPoints: Bool { true }
}
```

**ImageObject**
```swift
public struct ImageObject: CanvasObject {
    public var imageData: Data?
    public var aspectRatio: CGFloat
    // ... CanvasObject properties
}
```

---

### Tool System

#### CanvasTool Protocol

Protocol for all canvas tools.

```swift
public protocol CanvasTool {
    var toolType: DrawingTool { get }
    var metadata: ToolMetadata { get }

    // Gesture handling (all have default no-op implementations)
    func handleDragChanged(start: CGPoint, current: CGPoint, viewModel: CanvasViewModel)
    func handleDragEnded(start: CGPoint, end: CGPoint, viewModel: CanvasViewModel, shiftHeld: Bool)
    func handleClick(at: CGPoint, viewModel: CanvasViewModel, shiftHeld: Bool)

    // Preview rendering
    func renderPreview(start: CGPoint, current: CGPoint, viewModel: CanvasViewModel) -> AnyView
}
```

**Default Implementations:** All methods default to no-op. Override only what your tool needs.

---

#### DrawingTool

Lightweight value type identifying a tool.

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

**Built-in Tools:**
- `.select` - Selection and manipulation
- `.hand` - Pan canvas
- `.text` - Create text objects
- `.line` - Draw lines
- `.arrow` - Draw arrows
- `.rectangle`, `.oval`, `.triangle`, `.diamond`, `.star` - Shape tools

---

#### ToolMetadata

Metadata describing a tool.

```swift
public struct ToolMetadata {
    public let name: String
    public let category: ToolCategory
    public let cursorType: NSCursor

    public init(name: String, category: ToolCategory, cursorType: NSCursor = .crosshair)
}

public enum ToolCategory {
    case selection      // Select, Hand
    case shape          // Rectangle, Oval, etc.
    case drawing        // Line, Arrow, Pencil
    case annotation     // Text, Note
    case navigation     // Hand, Zoom
}
```

---

#### ToolRegistry

Singleton managing all registered tools.

```swift
@MainActor
public class ToolRegistry: ObservableObject {
    public static let shared: ToolRegistry

    public func register(_ tool: any CanvasTool)
    public func register<Obj: CopyableCanvasObject>(_ manifest: ToolManifest<Obj>)

    public func tool(for type: DrawingTool) -> (any CanvasTool)?
    public func tools(in category: ToolCategory) -> [any CanvasTool]
}
```

**Usage:**
```swift
// Register a tool (no new object type)
ToolRegistry.shared.register(SelectTool())

// Register a tool with new object type (auto-registers views + codable)
ToolRegistry.shared.register(StickerTool.manifest)
```

---

#### ToolManifest

Bundles a tool with its views and codable discriminator for new object types.

```swift
public struct ToolManifest<Obj: CopyableCanvasObject> {
    public let tool: any CanvasTool
    public let discriminator: String
    public let interactiveView: (Obj, Bool, CanvasViewModel) -> AnyView
    public let exportView: (Obj) -> AnyView

    public init(
        tool: any CanvasTool,
        discriminator: String,
        interactiveView: @escaping (Obj, Bool, CanvasViewModel) -> AnyView,
        exportView: @escaping (Obj) -> AnyView
    )
}
```

**Usage:**
```swift
// In StickerTool.swift
static let manifest = ToolManifest(
    tool: StickerTool(),
    discriminator: "sticker",
    interactiveView: { obj, isSelected, vm in
        AnyView(StickerObjectView(object: obj, isSelected: isSelected, viewModel: vm))
    },
    exportView: { obj in
        AnyView(ExportStickerObjectView(object: obj))
    }
)
```

One `register()` call handles tool, interactive view, export view, and clipboard serialization.

---

### Selection System

#### SelectionState

Manages selection state.

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
    public mutating func stopEditing()
}
```

---

#### SelectionBox

Bounding box for selected objects with handles.

```swift
public struct SelectionBox {
    public let bounds: CGRect
    public let individualBounds: [UUID: CGRect]
    public let center: CGPoint
    public let rotation: CGFloat

    public func hitTest(_ point: CGPoint) -> SelectionHitZone?
}

public enum SelectionHitZone {
    case move
    case corner(Corner)
    case edge(Edge)
    case rotation(Corner)
}
```

---

### Viewport System

#### ViewportState

Manages canvas pan/zoom.

```swift
public struct ViewportState {
    public var offset: CGPoint
    public var scale: CGFloat

    public let minScale: CGFloat
    public let maxScale: CGFloat

    // Coordinate conversion
    public func canvasPoint(from screenPoint: CGPoint) -> CGPoint
    public func screenPoint(from canvasPoint: CGPoint) -> CGPoint

    // Transformations
    public mutating func zoom(by factor: CGFloat, centeredOn point: CGPoint)
    public mutating func pan(by delta: CGPoint)
    public mutating func reset()
    public mutating func fitContent(_ contentBounds: CGRect, in viewSize: CGSize)
}
```

**Usage:**
```swift
// Programmatic viewport control
viewModel.viewport.scale = 2.0
viewModel.viewport.offset = CGPoint(x: 100, y: 100)

// Reset to default
viewModel.viewport.reset()

// Fit all objects in view
viewModel.viewport.fitContent(allObjectsBounds, in: canvasSize)
```

---

## Extension Guide

### Adding a Custom Tool (Existing Object Type)

1. **Create tool file** (`MyTool.swift`)
2. **Declare tool identity** via extension
3. **Implement CanvasTool protocol**
4. **Register tool**

```swift
// MyPencilTool.swift
import AnotarCanvas

extension DrawingTool {
    public static let pencil = DrawingTool(id: "pencil")
}

public struct PencilTool: CanvasTool {
    public let toolType: DrawingTool = .pencil

    public var metadata: ToolMetadata {
        ToolMetadata(name: "Pencil", category: .drawing)
    }

    public func handleDragEnded(
        start: CGPoint,
        end: CGPoint,
        viewModel: CanvasViewModel,
        shiftHeld: Bool
    ) {
        let line = LineObject(startPoint: start, endPoint: end, ...)
        viewModel.addObject(line)
    }
}

// Register
ToolRegistry.shared.register(PencilTool())
```

See [docs/adding-a-tool.md](adding-a-tool.md) for complete guide.

---

### Adding a Custom Object Type

1. **Create object model** conforming to `CopyableCanvasObject`
2. **Create interactive view**
3. **Create export view**
4. **Create tool with ToolManifest**
5. **Register manifest**

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

    // Required methods...
}

// 2. Interactive view
struct StickerObjectView: View {
    let object: StickerObject
    let isSelected: Bool
    @ObservedObject var viewModel: CanvasViewModel

    var body: some View {
        Text(object.emoji)
            .position(...)
    }
}

// 3. Export view (same as above for simple cases)

// 4. Tool with manifest
extension DrawingTool {
    public static let sticker = DrawingTool(id: "sticker")
}

public struct StickerTool: CanvasTool {
    public let toolType: DrawingTool = .sticker
    public var metadata: ToolMetadata { ... }

    public func handleClick(at point: CGPoint, viewModel: CanvasViewModel, shiftHeld: Bool) {
        viewModel.addObject(StickerObject(position: point, emoji: "⭐️"))
    }

    public static let manifest = ToolManifest(
        tool: StickerTool(),
        discriminator: "sticker",
        interactiveView: { obj, sel, vm in AnyView(StickerObjectView(...)) },
        exportView: { obj in AnyView(ExportStickerObjectView(...)) }
    )
}

// 5. Register (one line, registers everything)
ToolRegistry.shared.register(StickerTool.manifest)
```

---

## Architecture Principles

### Zero Core Modifications for Extensions

Adding a tool or object type **requires zero modifications to framework files**:
- ✅ No changes to `DrawingTool.swift` (identities declared per-file)
- ✅ No changes to `CanvasView.swift` (dispatches via registry)
- ✅ No changes to `CanvasViewModel.swift` (generic `addObject(_:)`)
- ✅ No changes to object rendering (ObjectViewRegistry)

### Separation of Concerns

| Layer | Responsibility | Examples |
|-------|---------------|----------|
| **Framework** | Canvas behavior, tool protocol, object model | `CanvasView`, `CanvasTool`, `CanvasObject` |
| **Application** | UI, keyboard shortcuts, icons, toolbar | `ToolbarView`, hotkeys, SF Symbol mapping |

Icons, keyboard shortcuts, and toolbar layout are **application concerns**, not framework concerns.

### Type Safety with Type Erasure

- Heterogeneous storage via `AnyCanvasObject`
- Type-safe retrieval via `.asType(_:)`
- Protocol-based capabilities (`TextContentObject`, `StrokableObject`)
- No casting to `Any` or forced unwrapping

---

## Examples

### Minimal Application

```swift
import SwiftUI
import AnotarCanvas

@main
struct MinimalApp: App {
    var body: some Scene {
        WindowGroup {
            MinimalCanvasView()
        }
    }
}

struct MinimalCanvasView: View {
    @StateObject private var viewModel = CanvasViewModel()

    var body: some View {
        CanvasView(viewModel: viewModel)
            .onAppear {
                viewModel.selectedTool = .rectangle
            }
    }
}
```

### Programmatic Object Creation

```swift
let viewModel = CanvasViewModel()

// Add a rectangle
let rect = ShapeObject(
    position: CGPoint(x: 100, y: 100),
    size: CGSize(width: 200, height: 150),
    svgPath: "M 0,0 L 100,0 L 100,100 L 0,100 Z",
    toolId: "rectangle",
    fillColor: .blue,
    fillOpacity: 0.3,
    strokeColor: .black,
    strokeWidth: 2
)
viewModel.addObject(rect)

// Add text
let text = TextObject(
    position: CGPoint(x: 50, y: 50),
    text: "Hello",
    textAttributes: TextAttributes(fontSize: 24, textColor: .black)
)
viewModel.addObject(text)
```

### Custom Shape Tool

```swift
extension DrawingTool {
    public static let hexagon = DrawingTool(id: "hexagon")
}

public class HexagonTool: BaseShapeTool {
    public override var metadata: ToolMetadata {
        ToolMetadata(name: "Hexagon", category: .shape)
    }

    public override var toolType: DrawingTool { .hexagon }

    public override var svgPath: String {
        "M 50,0 L 93,25 L 93,75 L 50,100 L 7,75 L 7,25 Z"
    }
}

// Register
ToolRegistry.shared.register(HexagonTool())
```

---

## See Also

- [Adding a Tool Guide](adding-a-tool.md) - Step-by-step guide for custom tools
- [ARCHITECTURE.md](../ARCHITECTURE.md) - Overall system architecture
- [CLAUDE.md](../CLAUDE.md) - Quick reference for AI assistants
