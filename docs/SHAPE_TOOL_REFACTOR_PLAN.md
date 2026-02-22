# Shape Tool Refactor: Tool-Defined Architecture (Simplified)

## Overview

Refactor the shape tool system from a single "ShapeTool with presets" pattern to a "each shape is its own tool" pattern. Each shape tool will define its own SVG path geometry directly, with no intermediate data structures needed.

## Goals

1. Make each shape (Rectangle, Oval, Triangle, etc.) a distinct, discoverable tool
2. Enable plugins to easily add new shapes without modifying core framework code
3. Keep the framework minimal - just geometry, no UI concerns (icons, shortcuts)
4. Align with industry patterns (Konva.js uses separate tools per shape)

## Architecture Principles

**Framework Responsibilities:**
- Tool behavior (drag to create, resize logic)
- Shape geometry (SVG paths)
- Tool categorization (for functional grouping)
- Cursor types (visual feedback during drawing)

**Application Responsibilities:**
- Icons (SF Symbols for toolbar/shape picker)
- Keyboard shortcuts (Cmd+C, tool selection keys)
- Tool ordering in UI
- Tooltips and labels

## Current Architecture

```swift
// Single tool with preset selection
public enum ShapePreset {
    case rectangle
    case oval
    case triangle

    var id: String { ... }
    var name: String { ... }
    var svgPath: String { ... }
    var iconName: String { ... }
}

public struct ShapeObject {
    public var preset: ShapePreset
}
```

## New Architecture

```swift
// Each shape is its own tool class
public class RectangleTool: ShapeTool {
    public var metadata: ToolMetadata {
        ToolMetadata(
            name: "Rectangle",
            category: .shape,
            cursorType: .crosshair
        )
    }

    public var toolType: DrawingTool { .rectangle }

    public var svgPath: String {
        "M 0,0 L 100,0 L 100,100 L 0,100 Z"
    }
}

// ShapeObject stores just the path and tool ID
public struct ShapeObject {
    public var svgPath: String  // The geometry
    public var toolId: String   // "rectangle" - for deserialization/reconstruction
    // ... position, size, fill, stroke, etc.
}
```

**Key simplifications:**
- No `ShapePreset` struct
- No `ShapeDefinition` struct
- No `iconName` in framework
- No `shortcutKey` in framework
- Just `svgPath: String` on the tool and object

## Implementation Steps

### Step 1: Clean Up ToolMetadata (Remove UI Concerns)

**File:** `AnotarCanvas/Models/Protocols/CanvasTool.swift`

**Remove** `icon` and `shortcutKey` from ToolMetadata:

```swift
/// Metadata describing a tool for framework purposes
public struct ToolMetadata {
    public let name: String
    public let category: ToolCategory
    public let cursorType: NSCursor

    public init(
        name: String,
        category: ToolCategory,
        cursorType: NSCursor = .crosshair
    ) {
        self.name = name
        self.category = category
        self.cursorType = cursorType
    }
}
```

**Rationale:**
- `icon`: UI concern, belongs in app layer (ToolbarView, ShapePickerView)
- `shortcutKey`: Keyboard handling was moved to app layer during framework extraction
- `name`: Keep for debugging, logging, plugin identification
- `category`: Keep for functional grouping (`.shape`, `.drawing`, `.annotation`)
- `cursorType`: Keep for canvas behavior (visual feedback during drawing)

### Step 2: Update ShapeObject to Store SVG Path Directly

**File:** `AnotarCanvas/Models/ShapeObject.swift`

**Change from:**
```swift
public struct ShapeObject: CanvasObject, FillableObject, StrokableObject, TextContentObject {
    public let id: UUID
    public var position: CGPoint
    public var size: CGSize
    public var rotation: CGFloat

    public var preset: ShapePreset  // ❌ Remove this

    public var fillColor: Color
    public var fillOpacity: Double
    public var strokeColor: Color
    public var strokeWidth: CGFloat
    public var text: String
    public var autoResizeHeight: Bool
}
```

**Change to:**
```swift
public struct ShapeObject: CanvasObject, FillableObject, StrokableObject, TextContentObject {
    public let id: UUID
    public var position: CGPoint
    public var size: CGSize
    public var rotation: CGFloat

    public var svgPath: String   // ✅ Just the geometry
    public var toolId: String    // ✅ "rectangle", "oval", etc. for deserialization

    public var fillColor: Color
    public var fillOpacity: Double
    public var strokeColor: Color
    public var strokeWidth: CGFloat
    public var text: String
    public var autoResizeHeight: Bool

    public init(
        id: UUID = UUID(),
        position: CGPoint,
        size: CGSize,
        rotation: CGFloat = 0,
        svgPath: String,
        toolId: String,
        fillColor: Color,
        fillOpacity: Double = 0.3,
        strokeColor: Color,
        strokeWidth: CGFloat = 2,
        text: String = "",
        autoResizeHeight: Bool = false
    ) {
        self.id = id
        self.position = position
        self.size = size
        self.rotation = rotation
        self.svgPath = svgPath
        self.toolId = toolId
        self.fillColor = fillColor
        self.fillOpacity = fillOpacity
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
        self.text = text
        self.autoResizeHeight = autoResizeHeight
    }

    // Keep existing methods: boundingBox(), contains(), etc.
}
```

### Step 3: Add Path Rendering Helper

**File:** `AnotarCanvas/Models/ShapeObject.swift`

Add helper to convert SVG path to SwiftUI Path:

```swift
extension ShapeObject {
    /// Convert the SVG path to a SwiftUI Path scaled to the object's size
    public func path() -> Path {
        SVGPath.parse(svgPath)
            .path(in: CGRect(origin: .zero, size: size))
    }
}
```

### Step 4: Create Base ShapeTool Class

**New file:** `AnotarCanvas/Tools/BaseShapeTool.swift`

```swift
import SwiftUI

/// Base class for all shape tools. Each shape tool defines its own SVG path geometry.
/// Subclasses only need to override `svgPath` and `toolType`.
open class ShapeTool: CanvasTool {

    public init() {}

    /// The SVG path defining the shape's geometry (must be overridden by subclasses)
    open var svgPath: String {
        fatalError("Subclasses must override svgPath")
    }

    /// Tool metadata (name comes from subclass, category is always .shape)
    open var metadata: ToolMetadata {
        fatalError("Subclasses must override metadata")
    }

    /// The DrawingTool type identifying this tool
    open var toolType: DrawingTool {
        fatalError("Subclasses must override toolType")
    }

    // MARK: - Shared Shape Creation Logic

    private var dragStartObject: AnyCanvasObject?

    public func handleDragChanged(
        start: CGPoint,
        current: CGPoint,
        viewModel: CanvasViewModel
    ) {
        // Calculate size and position
        let width = abs(current.x - start.x)
        let height = abs(current.y - start.y)
        let size = CGSize(width: width, height: height)

        let x = min(start.x, current.x)
        let y = min(start.y, current.y)
        let position = CGPoint(x: x, y: y)

        if dragStartObject == nil {
            // Create new shape object
            let shape = ShapeObject(
                position: position,
                size: size,
                svgPath: svgPath,
                toolId: toolType.id,
                fillColor: viewModel.activeFillColor ?? .blue,
                fillOpacity: 0.3,
                strokeColor: viewModel.activeStrokeColor ?? .black,
                strokeWidth: 2,
                autoResizeHeight: viewModel.autoResizeShapes
            )

            let anyObj = AnyCanvasObject(shape)
            viewModel.addObject(anyObj)
            dragStartObject = anyObj
        } else {
            // Update existing shape
            guard var shape = dragStartObject?.base as? ShapeObject else { return }
            shape.position = position
            shape.size = size
            viewModel.updateObject(AnyCanvasObject(shape))
        }
    }

    public func handleDragEnded(
        start: CGPoint,
        end: CGPoint,
        viewModel: CanvasViewModel,
        shiftHeld: Bool
    ) {
        dragStartObject = nil
    }

    public func renderPreview(
        start: CGPoint,
        current: CGPoint,
        viewModel: CanvasViewModel
    ) -> AnyView {
        // Optional: render preview during drag
        AnyView(EmptyView())
    }
}
```

### Step 5: Create Concrete Shape Tool Classes

**New directory:** `AnotarCanvas/Tools/Shapes/`

**RectangleTool.swift:**
```swift
import Foundation

public class RectangleTool: ShapeTool {
    public override var metadata: ToolMetadata {
        ToolMetadata(
            name: "Rectangle",
            category: .shape,
            cursorType: .crosshair
        )
    }

    public override var toolType: DrawingTool {
        .rectangle
    }

    public override var svgPath: String {
        "M 0,0 L 100,0 L 100,100 L 0,100 Z"
    }
}
```

**OvalTool.swift:**
```swift
import Foundation

public class OvalTool: ShapeTool {
    public override var metadata: ToolMetadata {
        ToolMetadata(
            name: "Oval",
            category: .shape,
            cursorType: .crosshair
        )
    }

    public override var toolType: DrawingTool {
        .oval
    }

    public override var svgPath: String {
        "M 50,0 A 50,50 0 1,1 50,100 A 50,50 0 1,1 50,0 Z"
    }
}
```

**TriangleTool.swift:**
```swift
import Foundation

public class TriangleTool: ShapeTool {
    public override var metadata: ToolMetadata {
        ToolMetadata(
            name: "Triangle",
            category: .shape,
            cursorType: .crosshair
        )
    }

    public override var toolType: DrawingTool {
        .triangle
    }

    public override var svgPath: String {
        "M 50,0 L 100,100 L 0,100 Z"
    }
}
```

**DiamondTool.swift:**
```swift
import Foundation

public class DiamondTool: ShapeTool {
    public override var metadata: ToolMetadata {
        ToolMetadata(
            name: "Diamond",
            category: .shape,
            cursorType: .crosshair
        )
    }

    public override var toolType: DrawingTool {
        .diamond
    }

    public override var svgPath: String {
        "M 50,0 L 100,50 L 50,100 L 0,50 Z"
    }
}
```

**StarTool.swift:**
```swift
import Foundation

public class StarTool: ShapeTool {
    public override var metadata: ToolMetadata {
        ToolMetadata(
            name: "Star",
            category: .shape,
            cursorType: .crosshair
        )
    }

    public override var toolType: DrawingTool {
        .star
    }

    public override var svgPath: String {
        "M 50,0 L 61,35 L 98,35 L 68,57 L 79,91 L 50,70 L 21,91 L 32,57 L 2,35 L 39,35 Z"
    }
}
```

### Step 6: Update DrawingTool

**File:** `AnotarCanvas/Models/DrawingTool.swift`

```swift
public struct DrawingTool: Hashable {
    public let id: String

    public init(id: String) {
        self.id = id
    }
}

public extension DrawingTool {
    static let select = DrawingTool(id: "select")
    static let hand = DrawingTool(id: "hand")
    static let text = DrawingTool(id: "text")
    static let line = DrawingTool(id: "line")
    static let arrow = DrawingTool(id: "arrow")

    // Built-in shape tools
    static let rectangle = DrawingTool(id: "rectangle")
    static let oval = DrawingTool(id: "oval")
    static let triangle = DrawingTool(id: "triangle")
    static let diamond = DrawingTool(id: "diamond")
    static let star = DrawingTool(id: "star")

    // Factory method for custom shapes (plugins)
    static func shape(id: String) -> DrawingTool {
        DrawingTool(id: id)
    }
}
```

### Step 7: Delete Old ShapeTool and ShapePreset Files

**Delete:**
- `AnotarCanvas/Tools/ShapeTool.swift` (old implementation)
- `AnotarCanvas/Models/ShapePreset.swift` (no longer needed)

### Step 8: Update ToolRegistry Initialization

**File:** `AnotarCanvas/Tools/ToolRegistry.swift`

Update the `shared` singleton:

```swift
public static let shared: ToolRegistry = {
    let registry = ToolRegistry()

    // Register core tools
    registry.register(SelectTool(), for: .select)
    registry.register(HandTool(), for: .hand)
    registry.register(TextTool(), for: .text)
    registry.register(LineTool(), for: .line)
    registry.register(ArrowTool(), for: .arrow)

    // Register all shape tools
    registry.register(RectangleTool(), for: .rectangle)
    registry.register(OvalTool(), for: .oval)
    registry.register(TriangleTool(), for: .triangle)
    registry.register(DiamondTool(), for: .diamond)
    registry.register(StarTool(), for: .star)

    return registry
}()
```

### Step 9: Update ShapePickerView (App Layer)

**File:** `texttool/Views/ShapePickerView.swift`

The app defines icons and presentation:

```swift
import SwiftUI
import AnotarCanvas

struct ShapePickerView: View {
    @ObservedObject var viewModel: CanvasViewModel
    @Binding var isPresented: Bool

    // App-defined icon mapping
    let shapeIcons: [(tool: DrawingTool, icon: String, name: String)] = [
        (.rectangle, "rectangle", "Rectangle"),
        (.oval, "circle", "Oval"),
        (.triangle, "triangle", "Triangle"),
        (.diamond, "diamond", "Diamond"),
        (.star, "star", "Star"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(shapeIcons, id: \.tool) { item in
                Button {
                    viewModel.selectedTool = item.tool
                    isPresented = false
                } label: {
                    HStack {
                        Image(systemName: item.icon)
                            .frame(width: 20)
                        Text(item.name)
                        Spacer()
                        if viewModel.selectedTool == item.tool {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .background(
                    viewModel.selectedTool == item.tool
                        ? Color.accentColor.opacity(0.1)
                        : Color.clear
                )
            }
        }
        .frame(width: 200)
    }
}
```

### Step 10: Update ShapeObjectView

**File:** `AnotarCanvas/Views/ShapeObjectView.swift`

Update to use `svgPath` instead of `preset`:

```swift
struct ShapeObjectView: View {
    let object: ShapeObject
    var isSelected: Bool = false
    @ObservedObject var viewModel: CanvasViewModel

    private var effectiveHeight: CGFloat {
        if object.autoResizeHeight && !object.text.isEmpty {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 16)
            ]
            let attributed = NSAttributedString(string: object.text, attributes: attributes)
            let bounds = attributed.boundingRect(
                with: NSSize(width: object.size.width - 32, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            )
            return max(object.size.height, ceil(bounds.height) + 24)
        }
        return object.size.height
    }

    var body: some View {
        ZStack {
            let height = effectiveHeight
            let shapeRect = CGRect(origin: .zero, size: CGSize(width: object.size.width, height: height))

            // Parse SVG path and render
            SVGPath.parse(object.svgPath)
                .path(in: shapeRect)
                .fill(object.fillColor.opacity(object.fillOpacity))
                .frame(width: object.size.width, height: height)

            SVGPath.parse(object.svgPath)
                .path(in: shapeRect)
                .stroke(object.strokeColor, lineWidth: object.strokeWidth)
                .frame(width: object.size.width, height: height)

            if !object.text.isEmpty {
                Text(object.text)
                    .font(.system(size: 16))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .frame(width: object.size.width - 16)
                    .padding(8)
            }
        }
        .rotationEffect(.radians(object.rotation))
        .position(
            x: object.position.x + object.size.width / 2,
            y: object.position.y + effectiveHeight / 2
        )
    }
}
```

### Step 11: Update CanvasExportView

**File:** `AnotarCanvas/Views/CanvasExportView.swift`

Update `ExportShapeObjectView` to use `svgPath`:

```swift
struct ExportShapeObjectView: View {
    let object: ShapeObject

    private var effectiveHeight: CGFloat {
        if object.autoResizeHeight && !object.text.isEmpty {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 16)
            ]
            let attributed = NSAttributedString(string: object.text, attributes: attributes)
            let bounds = attributed.boundingRect(
                with: NSSize(width: object.size.width - 32, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            )
            return max(object.size.height, ceil(bounds.height) + 24)
        }
        return object.size.height
    }

    var body: some View {
        ZStack {
            let height = effectiveHeight
            let shapeRect = CGRect(origin: .zero, size: CGSize(width: object.size.width, height: height))

            SVGPath.parse(object.svgPath)
                .path(in: shapeRect)
                .fill(object.fillColor.opacity(object.fillOpacity))
                .frame(width: object.size.width, height: height)

            SVGPath.parse(object.svgPath)
                .path(in: shapeRect)
                .stroke(object.strokeColor, lineWidth: object.strokeWidth)
                .frame(width: object.size.width, height: height)

            if !object.text.isEmpty {
                Text(object.text)
                    .font(.system(size: 16))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .frame(width: object.size.width - 16)
                    .padding(8)
            }
        }
        .rotationEffect(.radians(object.rotation))
        .position(
            x: object.position.x + object.size.width / 2,
            y: object.position.y + effectiveHeight / 2
        )
    }
}
```

### Step 12: Update Existing Tool Implementations

Remove `icon` and `shortcutKey` from all tool metadata.

**SelectTool.swift:**
```swift
public var metadata: ToolMetadata {
    ToolMetadata(
        name: "Select",
        category: .selection,
        cursorType: .arrow
    )
}
```

**HandTool.swift:**
```swift
public var metadata: ToolMetadata {
    ToolMetadata(
        name: "Hand",
        category: .navigation,
        cursorType: .openHand
    )
}
```

**TextTool.swift:**
```swift
public var metadata: ToolMetadata {
    ToolMetadata(
        name: "Text",
        category: .annotation,
        cursorType: .iBeam
    )
}
```

**LineTool.swift, ArrowTool.swift:** Similar pattern.

### Step 13: Update Tests

**Files to update:**
- `texttoolTests/ShapeObjectTests.swift`
- `texttoolTests/ShapeToolTests.swift`

**Changes:**
1. Remove references to `ShapePreset`
2. Update to use `svgPath` and `toolId`
3. Add tests for new concrete shape tools

**Example test:**
```swift
@Test func rectangleToolCreatesObject() async throws {
    let viewModel = CanvasViewModel()
    let rectangleTool = RectangleTool()

    rectangleTool.handleDragChanged(
        start: CGPoint(x: 100, y: 100),
        current: CGPoint(x: 200, y: 200),
        viewModel: viewModel
    )

    #expect(viewModel.objects.count == 1)

    let obj = viewModel.objects[0]
    let shape = try #require(obj.base as? ShapeObject)
    #expect(shape.toolId == "rectangle")
    #expect(shape.svgPath == "M 0,0 L 100,0 L 100,100 L 0,100 Z")
    #expect(shape.size.width == 100)
    #expect(shape.size.height == 100)
}

@Test func allShapeToolsRegistered() async throws {
    let registry = ToolRegistry.shared

    #expect(registry.tool(for: .rectangle) is RectangleTool)
    #expect(registry.tool(for: .oval) is OvalTool)
    #expect(registry.tool(for: .triangle) is TriangleTool)
    #expect(registry.tool(for: .diamond) is DiamondTool)
    #expect(registry.tool(for: .star) is StarTool)
}
```

### Step 14: Update ToolbarView

**File:** `texttool/Views/ToolbarView.swift`

Remove dependency on `metadata.icon` (line 66):

```swift
private var activeShapeIcon: String {
    // Map tool IDs to icons (app responsibility)
    let shapeIcons: [String: String] = [
        "rectangle": "rectangle",
        "oval": "circle",
        "triangle": "triangle",
        "diamond": "diamond",
        "star": "star",
    ]

    if let activeTool = toolRegistry.tool(for: viewModel.selectedTool),
       activeTool.metadata.category == .shape {
        return shapeIcons[viewModel.selectedTool.id] ?? "square.on.square"
    }

    return "square.on.square"
}
```

## File Structure After Refactor

```
AnotarCanvas/
├── Models/
│   ├── Protocols/
│   │   └── CanvasTool.swift          (updated: ToolMetadata simplified)
│   ├── ShapeObject.swift              (updated: svgPath + toolId, no preset)
│   ├── DrawingTool.swift              (updated: .rectangle, .oval, etc.)
│   └── ...
├── Tools/
│   ├── BaseShapeTool.swift            (new: base class for all shapes)
│   ├── Shapes/                        (new directory)
│   │   ├── RectangleTool.swift
│   │   ├── OvalTool.swift
│   │   ├── TriangleTool.swift
│   │   ├── DiamondTool.swift
│   │   └── StarTool.swift
│   ├── ToolRegistry.swift             (updated: register shape tools)
│   ├── SelectTool.swift               (updated: simplified metadata)
│   ├── HandTool.swift                 (updated: simplified metadata)
│   ├── TextTool.swift                 (updated: simplified metadata)
│   ├── LineTool.swift                 (updated: simplified metadata)
│   └── ArrowTool.swift                (updated: simplified metadata)
├── Views/
│   ├── ShapeObjectView.swift          (updated: use svgPath)
│   ├── CanvasExportView.swift         (updated: use svgPath)
│   └── ...
└── ...

texttool/
└── Views/
    ├── ShapePickerView.swift          (updated: app-defined icons)
    └── ToolbarView.swift              (updated: app-defined icons)
```

## Migration Checklist

- [ ] Step 1: Clean up ToolMetadata (remove icon, shortcutKey)
- [ ] Step 2: Update ShapeObject (svgPath + toolId, remove preset)
- [ ] Step 3: Add path rendering helper
- [ ] Step 4: Create BaseShapeTool class
- [ ] Step 5: Create concrete shape tool classes (5 files)
- [ ] Step 6: Update DrawingTool static properties
- [ ] Step 7: Delete old ShapeTool.swift and ShapePreset.swift
- [ ] Step 8: Update ToolRegistry initialization
- [ ] Step 9: Update ShapePickerView (app-defined icons)
- [ ] Step 10: Update ShapeObjectView (use svgPath)
- [ ] Step 11: Update CanvasExportView (use svgPath)
- [ ] Step 12: Update existing tool metadata (remove icon/shortcutKey)
- [ ] Step 13: Update all tests
- [ ] Step 14: Update ToolbarView (remove metadata.icon dependency)
- [ ] Build framework: `xcodebuild -scheme AnotarCanvas -configuration Debug build`
- [ ] Build app: `xcodebuild -scheme texttool -configuration Debug build`
- [ ] Run tests: `xcodebuild test -scheme texttool -only-testing:texttoolTests`

## Benefits of New Architecture

1. **Minimal Framework**: No UI concerns (icons, shortcuts) in framework layer
2. **Extensibility**: Plugins add shapes by creating one tool class
3. **Discoverability**: ToolRegistry knows about all registered shape tools
4. **Type Safety**: Each shape is a distinct type (RectangleTool vs OvalTool)
5. **Clarity**: No intermediate data structures - just `svgPath: String`
6. **App Flexibility**: App controls all UI presentation (icons, ordering, tooltips)
7. **Industry Alignment**: Matches Konva.js pattern (separate tool per shape)

## Example: Adding a Custom Shape (After Refactor)

**In a plugin:**

```swift
import AnotarCanvas

public class HexagonTool: ShapeTool {
    public override var metadata: ToolMetadata {
        ToolMetadata(
            name: "Hexagon",
            category: .shape,
            cursorType: .crosshair
        )
    }

    public override var toolType: DrawingTool {
        .shape(id: "com.myplugin.hexagon")
    }

    public override var svgPath: String {
        "M 50,0 L 93,25 L 93,75 L 50,100 L 7,75 L 7,25 Z"
    }
}

// Register it
ToolRegistry.shared.register(HexagonTool(), for: .shape(id: "com.myplugin.hexagon"))
```

**In the app (add icon):**

```swift
// ShapePickerView.swift
let shapeIcons: [(tool: DrawingTool, icon: String, name: String)] = [
    (.rectangle, "rectangle", "Rectangle"),
    (.oval, "circle", "Oval"),
    (.triangle, "triangle", "Triangle"),
    (.diamond, "diamond", "Diamond"),
    (.star, "star", "Star"),
    (.shape(id: "com.myplugin.hexagon"), "hexagon", "Hexagon"),  // Add icon mapping
]
```

That's it! Clean separation of concerns.
