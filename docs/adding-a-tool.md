# Adding a New Tool & Object Type

This guide walks through adding a new tool to the canvas app. It covers two scenarios:

1. **Tool only** — your tool creates an existing object type (e.g. a new shape preset)
2. **Tool + new object type** — your tool introduces a brand-new kind of canvas object

After the registry-based refactoring, adding a new object type touches **zero core files**. Everything is done through registration.

---

## Architecture at a Glance

```
CanvasView
  │  dispatches gestures via ──► ToolRegistry ──► CanvasTool plugins
  │  renders objects via ───────► ObjectViewRegistry ──► view factories
  │
CanvasViewModel
  │  stores ──► [AnyCanvasObject]  (type-erased, heterogeneous)
  │  clipboard ──► CodableObjectRegistry ──► encode/decode factories
```

**Key registries:**

| Registry | Purpose | Keyed by |
|----------|---------|----------|
| `ToolRegistry` | Maps `DrawingTool` → gesture handlers + preview | Tool ID string |
| `ObjectViewRegistry` | Maps object type → interactive & export SwiftUI views | `ObjectIdentifier` |
| `CodableObjectRegistry` | Maps object type → encode/decode for clipboard | Discriminator string |

---

## Scenario A: Tool Only (Existing Object Type)

If your tool creates objects that already exist (e.g. a "Star" tool that uses `ShapeObject` with a new preset), you only need:

1. Add a `DrawingTool` case (if needed)
2. Create the tool plugin
3. Register it
4. Add a toolbar button (if needed)

### Step 1 — Add a DrawingTool case

```swift
// Models/DrawingTool.swift
enum DrawingTool: Equatable {
    case select
    case text
    case shape(ShapePreset)
    case line
    case arrow
    case hand
    case pencil          // ← new case
}
```

### Step 2 — Create the tool plugin

Create `Tools/PencilToolPlugin.swift`:

```swift
import SwiftUI

struct PencilToolPlugin: CanvasTool {
    let id = "pencil-tool"
    let toolType: DrawingTool = .pencil

    var metadata: ToolMetadata {
        ToolMetadata(
            name: "Pencil",
            icon: "pencil",
            category: .drawing,
            cursorType: .crosshair,
            shortcutKey: "P"
        )
    }

    // Only override the methods your tool needs.
    // All CanvasTool methods have default no-op implementations.

    func handleDragChanged(
        start: CGPoint,
        current: CGPoint,
        viewModel: CanvasViewModel
    ) {
        if viewModel.dragStartPoint == nil {
            viewModel.dragStartPoint = start
        }
        viewModel.currentDragPoint = current
    }

    func renderPreview(
        start: CGPoint,
        current: CGPoint,
        viewModel: CanvasViewModel
    ) -> AnyView {
        AnyView(
            Path { path in
                path.move(to: start)
                path.addLine(to: current)
            }
            .stroke(viewModel.activeColor.opacity(0.5), lineWidth: 2)
        )
    }

    func handleDragEnded(
        start: CGPoint,
        end: CGPoint,
        viewModel: CanvasViewModel,
        shiftHeld: Bool
    ) {
        viewModel.addLine(from: start, to: end)
    }
}
```

### Step 3 — Register it

In `Tools/ToolRegistry.swift`, add to `registerBuiltInTools()`:

```swift
register(PencilToolPlugin())
```

Or register at runtime from anywhere:

```swift
ToolRegistry.shared.register(PencilToolPlugin())
```

### Step 4 — Add a toolbar button

In `Views/ToolbarView.swift`, add to the tool button row:

```swift
toolButton(.pencil, icon: "pencil", tooltip: "Pencil")
```

Done. No other files need changes.

---

## Scenario B: Tool + New Object Type

When your tool introduces a new kind of object (e.g. `StickerObject`), you need to:

1. Add a `DrawingTool` case
2. Create the data model struct
3. Create the interactive view
4. Create the export view
5. Create the tool plugin
6. Register everything in `ToolRegistry`
7. Add a toolbar button
8. Add tests

No modifications to `AnyCanvasObject`, `CanvasObjectView`, `CanvasExportView`, `CanvasViewModel`, or `CodableCanvasObject` are required.

### Step 1 — Add a DrawingTool case

```swift
// Models/DrawingTool.swift
case sticker
```

### Step 2 — Create the data model

Create `Models/StickerObject.swift`. Conform to `CopyableCanvasObject` (which implies `CanvasObject` + `Codable`) for full clipboard support.

```swift
import SwiftUI

struct StickerObject: CopyableCanvasObject {
    // MARK: - CanvasObject (required)
    let id: UUID
    var position: CGPoint
    var size: CGSize
    var rotation: CGFloat = 0
    var isLocked: Bool = false
    var zIndex: Int = 0

    // MARK: - Sticker-specific
    var emoji: String

    // MARK: - Init
    init(
        id: UUID = UUID(),
        position: CGPoint,
        size: CGSize = CGSize(width: 60, height: 60),
        emoji: String,
        rotation: CGFloat = 0,
        isLocked: Bool = false,
        zIndex: Int = 0
    ) {
        self.id = id
        self.position = position
        self.size = size
        self.emoji = emoji
        self.rotation = rotation
        self.isLocked = isLocked
        self.zIndex = zIndex
    }

    // MARK: - CanvasObject
    func contains(_ point: CGPoint) -> Bool {
        let localPoint = rotation != 0 ? transformToLocal(point) : point
        return CGRect(origin: position, size: size).contains(localPoint)
    }

    func boundingBox() -> CGRect {
        CGRect(origin: position, size: size)
    }

    // MARK: - CopyableCanvasObject
    func copied(newId: UUID, zIndex: Int, offset: CGPoint) -> StickerObject {
        StickerObject(
            id: newId,
            position: CGPoint(x: position.x + offset.x, y: position.y + offset.y),
            size: size,
            emoji: emoji,
            rotation: rotation,
            isLocked: false,
            zIndex: zIndex
        )
    }
}
```

#### CanvasObject protocol reference

Required properties and methods:

| Property/Method | Type | Notes |
|----------------|------|-------|
| `id` | `UUID` | Unique identifier (typically `let`) |
| `position` | `CGPoint` | Top-left corner of bounding box |
| `size` | `CGSize` | Bounding box dimensions |
| `rotation` | `CGFloat` | Radians, default `0` |
| `isLocked` | `Bool` | Prevents editing, default `false` |
| `zIndex` | `Int` | Render order (higher = on top) |
| `contains(_:)` | `(CGPoint) -> Bool` | Hit testing |
| `boundingBox()` | `() -> CGRect` | Has default impl: `CGRect(origin: position, size: size)` |
| `hitTest(_:threshold:)` | `(CGPoint, CGFloat) -> HitTestResult?` | Has default impl for rectangular objects |

#### Optional capability protocols

| Protocol | Properties | Use when |
|----------|-----------|----------|
| `TextContentObject` | `text`, `textAttributes`, `isEditing` | Object contains editable text |
| `StrokableObject` | `strokeColor`, `strokeWidth`, `strokeStyle` | Object has a stroke/border |
| `FillableObject` | `fillColor`, `fillOpacity` | Object has a fill color |

#### Capability flags

| Flag | Default | Override to `true` when |
|------|---------|----------------------|
| `usesControlPoints` | `false` | Object uses draggable control points instead of a selection box (like lines) |

### Step 3 — Create the interactive view

Create `Views/StickerObjectView.swift`:

```swift
import SwiftUI

struct StickerObjectView: View {
    let object: StickerObject
    let isSelected: Bool
    @ObservedObject var viewModel: CanvasViewModel

    var body: some View {
        Text(object.emoji)
            .font(.system(size: min(object.size.width, object.size.height) * 0.8))
            .frame(width: object.size.width, height: object.size.height)
            .rotationEffect(.radians(object.rotation))
            .position(
                x: object.position.x + object.size.width / 2,
                y: object.position.y + object.size.height / 2
            )
    }
}
```

### Step 4 — Create the export view

Create `Views/ExportStickerObjectView.swift` (or add it to `CanvasExportView.swift`):

```swift
import SwiftUI

struct ExportStickerObjectView: View {
    let object: StickerObject

    var body: some View {
        Text(object.emoji)
            .font(.system(size: min(object.size.width, object.size.height) * 0.8))
            .frame(width: object.size.width, height: object.size.height)
            .rotationEffect(.radians(object.rotation))
            .position(
                x: object.position.x + object.size.width / 2,
                y: object.position.y + object.size.height / 2
            )
    }
}
```

### Step 5 — Create the tool plugin

Create `Tools/StickerToolPlugin.swift`:

```swift
import SwiftUI

struct StickerToolPlugin: CanvasTool {
    let id = "sticker-tool"
    let toolType: DrawingTool = .sticker

    var metadata: ToolMetadata {
        ToolMetadata(
            name: "Sticker",
            icon: "face.smiling",
            category: .annotation,
            cursorType: .crosshair,
            shortcutKey: "K"
        )
    }

    func handleClick(
        at point: CGPoint,
        viewModel: CanvasViewModel,
        shiftHeld: Bool
    ) {
        let sticker = StickerObject(position: point, emoji: "⭐️")
        viewModel.addObject(sticker)
    }
}
```

The generic `viewModel.addObject(_:)` method works with any `CanvasObject`. No need to add type-specific helper methods to the view model.

### Step 6 — Register everything

In `Tools/ToolRegistry.swift`:

```swift
// In registerBuiltInTools():
register(StickerToolPlugin())

// In registerBuiltInObjectTypes():

// Interactive view
ObjectViewRegistry.register(StickerObject.self) { obj, isSelected, vm in
    AnyView(StickerObjectView(object: obj, isSelected: isSelected, viewModel: vm))
}

// Export view
ObjectViewRegistry.registerExport(StickerObject.self) { obj in
    AnyView(ExportStickerObjectView(object: obj))
}

// Clipboard support
CodableObjectRegistry.register(StickerObject.self, discriminator: "sticker")
```

### Step 7 — Add a toolbar button

In `Views/ToolbarView.swift`:

```swift
toolButton(.sticker, icon: "face.smiling", tooltip: "Sticker")
```

### Step 8 — Add tests

```swift
// texttoolTests/ToolTests.swift

@MainActor
@Suite(.serialized)
struct StickerToolTests {

    @Test func stickerToolClickCreatesObject() {
        let vm = CanvasViewModel()
        vm.selectedTool = .sticker

        let tool = StickerToolPlugin()
        tool.handleClick(at: CGPoint(x: 100, y: 100), viewModel: vm, shiftHeld: false)

        #expect(vm.objects.count == 1)
        #expect(vm.objects.first?.asType(StickerObject.self) != nil)
    }

    @Test func stickerObjectCodableRoundTrip() throws {
        _ = ToolRegistry.shared  // ensures registrations happen

        let original = StickerObject(position: CGPoint(x: 10, y: 20), emoji: "🎉")
        let wrapped = AnyCanvasObject(original)
        let codable = CodableCanvasObject.from(wrapped)!

        let data = try JSONEncoder().encode(codable)
        let decoded = try JSONDecoder().decode(CodableCanvasObject.self, from: data)
        let restored = decoded.toAnyCanvasObject(newId: UUID(), zIndex: 0, offset: .zero)

        #expect(restored != nil)
        #expect(restored?.asType(StickerObject.self)?.emoji == "🎉")
    }
}
```

---

## CanvasTool Protocol Reference

All methods have default no-op implementations. Only override what your tool needs.

| Method | When called | Typical use |
|--------|-------------|-------------|
| `renderPreview(start:current:viewModel:)` | Every frame during drag | Show ghost/outline while creating |
| `handleDragChanged(start:current:viewModel:)` | Each drag move event | Update `dragStartPoint`/`currentDragPoint` |
| `handleDragEnded(start:end:viewModel:shiftHeld:)` | Drag release (distance >= 5px) | Create the final object |
| `handleClick(at:viewModel:shiftHeld:)` | Tap/click (distance < 5px) | Click-to-place tools (text, sticker) |
| `matches(_:)` | Tool lookup in registry | Override to match multiple `DrawingTool` variants (e.g. `ShapeToolPlugin` matches all `.shape(_)`) |

## Tool Categories

| Category | Examples | Typical use |
|----------|----------|-------------|
| `.selection` | Select, Hand | Navigation and manipulation |
| `.shape` | Rectangle, Oval, Triangle | Geometric shapes |
| `.drawing` | Line, Arrow, Pencil | Freeform drawing |
| `.annotation` | Text, Sticker, Note | Content placement |
| `.navigation` | Hand, Zoom | Canvas navigation |

## Files Created vs Modified (Summary)

### Tool only (existing object type)

| File | Action |
|------|--------|
| `Models/DrawingTool.swift` | Add enum case |
| `Tools/YourToolPlugin.swift` | **New** — tool plugin |
| `Tools/ToolRegistry.swift` | Add `register()` call |
| `Views/ToolbarView.swift` | Add toolbar button |

### Tool + new object type

| File | Action |
|------|--------|
| `Models/DrawingTool.swift` | Add enum case |
| `Models/YourObject.swift` | **New** — data model |
| `Views/YourObjectView.swift` | **New** — interactive view |
| `Views/ExportYourObjectView.swift` | **New** — export view |
| `Tools/YourToolPlugin.swift` | **New** — tool plugin |
| `Tools/ToolRegistry.swift` | Add registrations (tool + view + export + codable) |
| `Views/ToolbarView.swift` | Add toolbar button |

Zero modifications to `AnyCanvasObject`, `CanvasObjectView`, `CanvasExportView`, `CanvasViewModel`, or `CodableCanvasObject`.
