# Plugin-Based Tool Architecture Design

## Problem Statement

### Current Issues

1. **CanvasView has hardcoded tool/object rendering logic**
   - Lines 66-116 in CanvasView.swift contain manual conditional checks for shape preview, line preview
   - Adding a new tool requires modifying CanvasView, CanvasViewModel, DrawingTool enum, ToolbarView, etc.
   - Multiple components are tightly coupled

2. **Toolbar tightly coupled to application**
   - ToolbarView knows about all tools and their specifics
   - Cannot reuse annotation core in other applications without bringing toolbar dependencies

3. **Tool registration is manual**
   - Adding new tools requires changes to multiple files:
     - DrawingTool enum
     - CanvasView (preview rendering)
     - CanvasView (gesture handling)
     - ToolbarView (UI buttons)
     - CanvasViewModel (object creation)

## Proposed Solution: Plugin-Based Tool Architecture

### Architecture Overview

```
┌─────────────────────────────────────────────────┐
│           Application Layer                      │
│  ┌──────────────────────────────────────────┐   │
│  │        ToolbarView (Optional)            │   │
│  │  - Renders registered tools              │   │
│  │  - Application-specific styling          │   │
│  └──────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────┐
│         Annotation Core (Reusable)              │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │        CanvasView                         │   │
│  │  - Tool-agnostic rendering                │   │
│  │  - Uses ToolRegistry for dispatch         │   │
│  └──────────────────────────────────────────┘   │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │        ToolRegistry (Singleton)           │   │
│  │  - Registered tools                       │   │
│  │  - Tool lifecycle management              │   │
│  └──────────────────────────────────────────┘   │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │        CanvasTool Protocol                │   │
│  │  - renderPreview()                        │   │
│  │  - handleDragChanged()                    │   │
│  │  - handleDragEnded()                      │   │
│  │  - renderObject()                         │   │
│  └──────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────┐
│         Tool Implementations                     │
│  ┌──────────────────────────────────────────┐   │
│  │  ShapeTool, LineTool, ArrowTool, etc.    │   │
│  │  - Each implements CanvasTool protocol    │   │
│  │  - Self-contained logic                   │   │
│  └──────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
```

## Key Components

### 1. CanvasTool Protocol (Core Abstraction)

```swift
/// Protocol that all canvas tools must implement
protocol CanvasTool {
    /// Unique identifier for this tool
    var id: String { get }

    /// Tool metadata for UI rendering
    var metadata: ToolMetadata { get }

    /// The DrawingTool enum case this tool handles
    var toolType: DrawingTool { get }

    /// Render preview during drag operation (optional)
    /// - Parameters:
    ///   - start: Drag start point in canvas coordinates
    ///   - current: Current drag point in canvas coordinates
    ///   - viewModel: Canvas view model for accessing state
    /// - Returns: SwiftUI view for preview
    @ViewBuilder
    func renderPreview(
        start: CGPoint,
        current: CGPoint,
        viewModel: CanvasViewModel
    ) -> some View

    /// Handle drag gesture changed event
    /// - Parameters:
    ///   - start: Drag start point in canvas coordinates
    ///   - current: Current drag point in canvas coordinates
    ///   - viewModel: Canvas view model for state updates
    func handleDragChanged(
        start: CGPoint,
        current: CGPoint,
        viewModel: CanvasViewModel
    )

    /// Finalize object creation when drag ends
    /// - Parameters:
    ///   - start: Drag start point in canvas coordinates
    ///   - end: Drag end point in canvas coordinates
    ///   - viewModel: Canvas view model for object creation
    ///   - shiftHeld: Whether shift key is held for constraints
    func handleDragEnded(
        start: CGPoint,
        end: CGPoint,
        viewModel: CanvasViewModel,
        shiftHeld: Bool
    )

    /// Render the actual object on canvas
    /// - Parameters:
    ///   - object: The canvas object to render
    ///   - isSelected: Whether the object is selected
    ///   - viewModel: Canvas view model for context
    /// - Returns: SwiftUI view for the object
    @ViewBuilder
    func renderObject(
        _ object: AnyCanvasObject,
        isSelected: Bool,
        viewModel: CanvasViewModel
    ) -> some View

    /// Handle click event (optional, default does nothing)
    func handleClick(
        at point: CGPoint,
        viewModel: CanvasViewModel,
        shiftHeld: Bool
    )
}

// Default implementations
extension CanvasTool {
    func handleClick(
        at point: CGPoint,
        viewModel: CanvasViewModel,
        shiftHeld: Bool
    ) {
        // Default: no-op for tools that don't need click handling
    }
}

/// Metadata describing a tool for UI purposes
struct ToolMetadata {
    let name: String
    let icon: String              // SF Symbol name
    let category: ToolCategory
    let cursorType: NSCursor
    let shortcutKey: String?      // Optional keyboard shortcut (e.g., "V" for select)
}

enum ToolCategory: String, CaseIterable {
    case selection    // Select, Hand
    case shape        // Rectangle, Circle, etc.
    case drawing      // Line, Arrow, Pencil, Highlighter
    case annotation   // Text, Note, Auto-number
    case navigation   // Hand, Zoom
}
```

### 2. ToolRegistry (Dynamic Registration)

```swift
/// Singleton registry managing all available tools
@MainActor
class ToolRegistry: ObservableObject {
    static let shared = ToolRegistry()

    @Published private(set) var registeredTools: [String: any CanvasTool] = [:]

    private init() {
        // Register built-in tools on initialization
        registerBuiltInTools()
    }

    /// Register a new tool
    /// - Parameter tool: Tool instance conforming to CanvasTool
    func register(_ tool: any CanvasTool) {
        registeredTools[tool.id] = tool
        objectWillChange.send()
    }

    /// Unregister a tool by ID
    /// - Parameter id: Tool identifier
    func unregister(id: String) {
        registeredTools.removeValue(forKey: id)
        objectWillChange.send()
    }

    /// Get tool instance for a given DrawingTool type
    /// - Parameter type: The DrawingTool enum case
    /// - Returns: Tool instance or nil if not found
    func tool(for type: DrawingTool) -> (any CanvasTool)? {
        registeredTools.values.first { $0.toolType == type }
    }

    /// Get all tools in a specific category
    /// - Parameter category: Tool category to filter by
    /// - Returns: Array of tools in the category
    func tools(in category: ToolCategory) -> [any CanvasTool] {
        registeredTools.values.filter { $0.metadata.category == category }
    }

    /// Get all registered tool IDs
    var toolIds: [String] {
        Array(registeredTools.keys)
    }

    private func registerBuiltInTools() {
        // Selection & Navigation
        register(SelectTool())
        register(HandTool())

        // Shapes
        register(ShapeTool())

        // Drawing
        register(LineTool())
        register(ArrowTool())

        // Annotation
        register(TextTool())
    }
}
```

### 3. Refactored CanvasView (Tool-Agnostic)

```swift
struct CanvasView: View {
    @ObservedObject var viewModel: CanvasViewModel
    @StateObject private var toolRegistry = ToolRegistry.shared

    // ... existing state variables ...

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Infinite canvas background with dot grid
                InfiniteGridView(viewport: viewModel.viewport)

                // Canvas content with viewport transform
                ZStack {
                    // Render all objects in zIndex order
                    ForEach(viewModel.objects) { obj in
                        CanvasObjectView(
                            object: obj,
                            isSelected: viewModel.isSelected(obj.id),
                            viewModel: viewModel
                        )
                    }

                    // Generic tool preview rendering - NO HARDCODED TOOL LOGIC
                    if let start = viewModel.dragStartPoint,
                       let current = viewModel.currentDragPoint,
                       let tool = toolRegistry.tool(for: viewModel.selectedTool) {
                        tool.renderPreview(
                            start: start,
                            current: current,
                            viewModel: viewModel
                        )
                    }
                }
                .scaleEffect(viewModel.viewport.scale, anchor: .topLeading)
                .offset(x: viewModel.viewport.offset.x, y: viewModel.viewport.offset.y)

                // Selection box overlay (unchanged)
                if activeHandleZone == nil,
                   let selectionBox = viewModel.selectionBox,
                   viewModel.selectedTool == .select,
                   !viewModel.isAnyObjectEditing,
                   !viewModel.isLineOnlySelection {
                    let screenBox = selectionBox.toScreen(viewport: viewModel.viewport)
                    SelectionBoxView(
                        selectionBox: screenBox,
                        viewModel: viewModel
                    )
                }

                // Marquee selection preview (unchanged)
                if isMarqueeSelecting,
                   let start = marqueeStart,
                   let end = marqueeEnd {
                    MarqueeView(startPoint: start, currentPoint: end)
                }
            }
            .clipped()
            .onAppear {
                canvasSize = geometry.size
                installKeyMonitor()
            }
            // ... rest of view setup ...
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { handleDragChanged($0) }
                .onEnded { handleDragEnded($0) }
        )
        // ... gesture handlers ...
    }

    // MARK: - Simplified Gesture Handling

    private func handleDragChanged(_ value: DragGesture.Value) {
        // Handle hand tool panning (unchanged)
        if viewModel.selectedTool == .hand {
            // ... existing hand tool logic ...
            return
        }

        let canvasStart = viewModel.viewport.screenToCanvas(value.startLocation)
        let canvasLocation = viewModel.viewport.screenToCanvas(value.location)

        // Delegate to tool via registry
        if let tool = toolRegistry.tool(for: viewModel.selectedTool) {
            tool.handleDragChanged(
                start: canvasStart,
                current: canvasLocation,
                viewModel: viewModel
            )
            return
        }

        // Select tool has special logic (kept inline for performance)
        if viewModel.selectedTool == .select {
            // ... existing select tool logic ...
        }
    }

    private func handleDragEnded(_ value: DragGesture.Value) {
        // Handle hand tool panning end (unchanged)
        if viewModel.selectedTool == .hand {
            // ... existing logic ...
            return
        }

        let distance = hypot(
            value.location.x - value.startLocation.x,
            value.location.y - value.startLocation.y
        )

        let canvasStart = viewModel.viewport.screenToCanvas(value.startLocation)
        let canvasLocation = viewModel.viewport.screenToCanvas(value.location)
        let shiftHeld = NSEvent.modifierFlags.contains(.shift)

        // Handle marquee selection completion (unchanged)
        if isMarqueeSelecting {
            // ... existing marquee logic ...
            return
        }

        // If it's a click (minimal drag)
        if distance < 5 {
            handleClick(at: value.location)
        } else {
            // Delegate to tool via registry
            if let tool = toolRegistry.tool(for: viewModel.selectedTool) {
                tool.handleDragEnded(
                    start: canvasStart,
                    end: canvasLocation,
                    viewModel: viewModel,
                    shiftHeld: shiftHeld
                )
            }
        }

        // Reset drag state
        viewModel.dragStartPoint = nil
        viewModel.currentDragPoint = nil
        draggedObjectId = nil
        lastDragLocation = nil
        // ... rest of cleanup ...
    }

    private func handleClick(at screenLocation: CGPoint) {
        let canvasLocation = viewModel.viewport.screenToCanvas(screenLocation)
        let shiftHeld = NSEvent.modifierFlags.contains(.shift)

        // Delegate to tool via registry
        if let tool = toolRegistry.tool(for: viewModel.selectedTool) {
            tool.handleClick(
                at: canvasLocation,
                viewModel: viewModel,
                shiftHeld: shiftHeld
            )
            return
        }

        // Fallback for select tool (kept inline for performance)
        if viewModel.selectedTool == .select {
            // ... existing select tool click logic ...
        }
    }
}
```

### 4. Example Tool Implementations

#### ShapeTool

```swift
struct ShapeTool: CanvasTool {
    let id = "shape-tool"
    let toolType: DrawingTool = .shape(.rectangle)

    var metadata: ToolMetadata {
        ToolMetadata(
            name: "Shape",
            icon: "square.on.square",
            category: .shape,
            cursorType: .crosshair,
            shortcutKey: "R"
        )
    }

    func renderPreview(
        start: CGPoint,
        current: CGPoint,
        viewModel: CanvasViewModel
    ) -> some View {
        Group {
            if let preset = viewModel.selectedTool.shapePreset {
                let shiftHeld = NSEvent.modifierFlags.contains(.shift)
                let rawWidth = abs(current.x - start.x)
                let rawHeight = abs(current.y - start.y)
                let constrain = shiftHeld
                let width = constrain ? max(rawWidth, rawHeight) : rawWidth
                let height = constrain ? max(rawWidth, rawHeight) : rawHeight
                let x = min(start.x, current.x) + width / 2
                let y = min(start.y, current.y) + height / 2
                let previewRect = CGRect(origin: .zero, size: CGSize(width: width, height: height))

                preset.path(in: previewRect)
                    .stroke(viewModel.activeColor.opacity(0.5), lineWidth: 2)
                    .frame(width: width, height: height)
                    .position(x: x, y: y)
            }
        }
    }

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

    func handleDragEnded(
        start: CGPoint,
        end: CGPoint,
        viewModel: CanvasViewModel,
        shiftHeld: Bool
    ) {
        guard let preset = viewModel.selectedTool.shapePreset else { return }

        let finalEnd: CGPoint
        if shiftHeld {
            let rawWidth = abs(end.x - start.x)
            let rawHeight = abs(end.y - start.y)
            let side = max(rawWidth, rawHeight)
            finalEnd = CGPoint(
                x: start.x + (end.x >= start.x ? side : -side),
                y: start.y + (end.y >= start.y ? side : -side)
            )
        } else {
            finalEnd = end
        }

        viewModel.addShape(preset: preset, from: start, to: finalEnd)
    }

    func renderObject(
        _ object: AnyCanvasObject,
        isSelected: Bool,
        viewModel: CanvasViewModel
    ) -> some View {
        Group {
            if let shape = object.asShapeObject {
                ShapeObjectView(
                    object: shape,
                    isSelected: isSelected,
                    viewModel: viewModel
                )
            }
        }
    }
}
```

#### LineTool

```swift
struct LineTool: CanvasTool {
    let id = "line-tool"
    let toolType: DrawingTool = .line

    var metadata: ToolMetadata {
        ToolMetadata(
            name: "Line",
            icon: "line.diagonal",
            category: .drawing,
            cursorType: .crosshair,
            shortcutKey: "L"
        )
    }

    func renderPreview(
        start: CGPoint,
        current: CGPoint,
        viewModel: CanvasViewModel
    ) -> some View {
        let shiftHeld = NSEvent.modifierFlags.contains(.shift)
        let end = shiftHeld ? constrainToAngle(from: start, to: current) : current

        return Path { path in
            path.move(to: start)
            path.addLine(to: end)
        }
        .stroke(viewModel.activeColor.opacity(0.5), lineWidth: 2)
    }

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

    func handleDragEnded(
        start: CGPoint,
        end: CGPoint,
        viewModel: CanvasViewModel,
        shiftHeld: Bool
    ) {
        let finalEnd = shiftHeld ? constrainToAngle(from: start, to: end) : end
        viewModel.addLine(from: start, to: finalEnd, asArrow: false)
    }

    func renderObject(
        _ object: AnyCanvasObject,
        isSelected: Bool,
        viewModel: CanvasViewModel
    ) -> some View {
        Group {
            if let line = object.asLineObject {
                LineObjectView(
                    object: line,
                    isSelected: isSelected,
                    viewModel: viewModel
                )
            }
        }
    }

    private func constrainToAngle(from start: CGPoint, to end: CGPoint) -> CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let distance = hypot(dx, dy)
        let angle = atan2(dy, dx)
        let snapAngle = CGFloat.pi / 12
        let snappedAngle = (angle / snapAngle).rounded() * snapAngle
        return CGPoint(
            x: start.x + distance * cos(snappedAngle),
            y: start.y + distance * sin(snappedAngle)
        )
    }
}
```

#### TextTool

```swift
struct TextTool: CanvasTool {
    let id = "text-tool"
    let toolType: DrawingTool = .text

    var metadata: ToolMetadata {
        ToolMetadata(
            name: "Text",
            icon: "textformat",
            category: .annotation,
            cursorType: .iBeam,
            shortcutKey: "T"
        )
    }

    func renderPreview(
        start: CGPoint,
        current: CGPoint,
        viewModel: CanvasViewModel
    ) -> some View {
        EmptyView() // Text tool doesn't show preview
    }

    func handleDragChanged(
        start: CGPoint,
        current: CGPoint,
        viewModel: CanvasViewModel
    ) {
        // No-op for text tool
    }

    func handleDragEnded(
        start: CGPoint,
        end: CGPoint,
        viewModel: CanvasViewModel,
        shiftHeld: Bool
    ) {
        // No-op for text tool (click-to-place)
    }

    func handleClick(
        at point: CGPoint,
        viewModel: CanvasViewModel,
        shiftHeld: Bool
    ) {
        let isEditing = viewModel.isAnyObjectEditing

        // Check if clicking on existing object
        if let objectId = viewModel.selectObject(at: point) {
            viewModel.startEditing(objectId: objectId)
        } else if isEditing {
            // Currently editing - just commit without creating new
            viewModel.deselectAll()
        } else {
            // Not editing - create new text object
            let newId = viewModel.addTextObject(at: point)
            viewModel.startEditing(objectId: newId)
        }
    }

    func renderObject(
        _ object: AnyCanvasObject,
        isSelected: Bool,
        viewModel: CanvasViewModel
    ) -> some View {
        Group {
            if let text = object.asTextObject {
                TextObjectView(
                    object: text,
                    isSelected: isSelected,
                    viewModel: viewModel
                )
            }
        }
    }
}
```

## Project Organization

### File Structure

```
texttool/
├── AnnotationCore/                    # 📦 Reusable Framework
│   ├── Models/
│   │   ├── Protocols/
│   │   │   ├── CanvasObject.swift
│   │   │   ├── CanvasTool.swift           # NEW
│   │   │   ├── TextContentObject.swift
│   │   │   ├── StrokableObject.swift
│   │   │   └── FillableObject.swift
│   │   ├── Objects/
│   │   │   ├── TextObject.swift
│   │   │   ├── ShapeObject.swift
│   │   │   ├── LineObject.swift
│   │   │   └── ...
│   │   ├── AnyCanvasObject.swift
│   │   ├── DrawingTool.swift
│   │   ├── ToolMetadata.swift             # NEW
│   │   └── ...
│   │
│   ├── ViewModels/
│   │   ├── CanvasViewModel.swift
│   │   ├── SelectionState.swift
│   │   └── ViewportState.swift
│   │
│   ├── Views/
│   │   ├── CanvasView.swift               # Refactored (tool-agnostic)
│   │   ├── CanvasObjectView.swift
│   │   ├── Selection/
│   │   │   ├── SelectionBoxView.swift
│   │   │   └── ResizeHandle.swift
│   │   └── ...
│   │
│   ├── Tools/                              # NEW
│   │   ├── ToolRegistry.swift             # NEW
│   │   ├── SelectTool.swift               # NEW
│   │   ├── HandTool.swift                 # NEW
│   │   ├── ShapeTool.swift                # NEW
│   │   ├── LineTool.swift                 # NEW
│   │   ├── ArrowTool.swift                # NEW
│   │   └── TextTool.swift                 # NEW
│   │
│   └── AnnotationCore.h                    # Framework public header
│
└── texttool/                            # 📱 Application Layer
    ├── texttoolApp.swift
    ├── ContentView.swift
    ├── Views/
    │   └── ToolbarView.swift              # App-specific toolbar
    └── Assets.xcassets/
```

### Target Configuration

```
# Current structure (single target)
texttool (macOS App)

# Proposed structure (framework + app)
AnnotationCore (macOS Framework)
  ↑
  └── texttool (macOS App)
```

## Benefits

### 1. Zero Code Changes to Add New Tools

```swift
// To add a new tool, just implement the protocol and register:
struct HighlighterTool: CanvasTool {
    // ... implement protocol ...
}

// In app initialization:
ToolRegistry.shared.register(HighlighterTool())
```

No changes needed to:
- CanvasView
- CanvasViewModel
- ToolbarView (automatically discovers registered tools)
- Any other core components

### 2. CanvasView Becomes Tool-Agnostic

**Before** (919 lines with hardcoded tool logic):
```swift
// Lines 66-116: Hardcoded shape preview
if let preset = viewModel.selectedTool.shapePreset,
   let start = viewModel.dragStartPoint,
   let current = viewModel.currentDragPoint {
    // ... shape-specific rendering ...
}

// Lines 88-116: Hardcoded line/arrow preview
if viewModel.selectedTool.isLineTool,
   let start = viewModel.dragStartPoint,
   let current = viewModel.currentDragPoint {
    // ... line-specific rendering ...
}
```

**After**:
```swift
// Single generic preview renderer
if let start = viewModel.dragStartPoint,
   let current = viewModel.currentDragPoint,
   let tool = toolRegistry.tool(for: viewModel.selectedTool) {
    tool.renderPreview(start: start, current: current, viewModel: viewModel)
}
```

### 3. Toolbar is Optional and Application-Specific

```swift
// Minimal app without toolbar
struct MinimalAnnotationApp: View {
    @StateObject private var viewModel = CanvasViewModel()

    var body: some View {
        CanvasView(viewModel: viewModel)
            .onAppear {
                // Programmatically select tool
                viewModel.selectedTool = .select
            }
    }
}

// Full-featured app with custom toolbar
struct FullFeaturedApp: View {
    @StateObject private var viewModel = CanvasViewModel()

    var body: some View {
        VStack {
            CustomToolbarView(viewModel: viewModel) // App-specific
            CanvasView(viewModel: viewModel)
        }
    }
}
```

### 4. Clean Separation of Concerns

| Component | Responsibility | Dependencies |
|-----------|---------------|--------------|
| AnnotationCore (Framework) | Canvas rendering, object management, tool protocol | None (standalone) |
| Tool Implementations | Tool-specific logic | AnnotationCore |
| Application Layer | UI, toolbar, app-specific features | AnnotationCore |

### 5. Independently Testable

```swift
// Test a tool in isolation
@Test func testShapeToolPreview() async throws {
    let viewModel = CanvasViewModel()
    let tool = ShapeTool()

    viewModel.selectedTool = .shape(.rectangle)
    viewModel.activeColor = .blue

    let preview = tool.renderPreview(
        start: CGPoint(x: 0, y: 0),
        current: CGPoint(x: 100, y: 100),
        viewModel: viewModel
    )

    // Assert preview is rendered correctly
    #expect(preview != nil)
}
```

### 6. Runtime Extensibility

```swift
// Third-party tools can be registered at runtime
class ThirdPartyToolPlugin {
    func install() {
        ToolRegistry.shared.register(CustomStampTool())
        ToolRegistry.shared.register(CustomBrushTool())
    }
}
```

---

### Protocol Reference

All methods have default no-op implementations. Only override what your tool needs.

| Method | When called | Typical use |
|--------|-------------|-------------|
| `renderPreview(start:current:viewModel:)` | Every frame during drag | Show ghost/outline of object being created |
| `handleDragChanged(start:current:viewModel:)` | Each drag move event | Update `dragStartPoint`/`currentDragPoint` on viewModel |
| `handleDragEnded(start:end:viewModel:shiftHeld:)` | Drag release (distance ≥ 5px) | Create the final object |
| `handleClick(at:viewModel:shiftHeld:)` | Tap / click (distance < 5px) | Click-to-place tools (text, sticker) |
| `matches(_:)` | Tool lookup in registry | Override to match multiple `DrawingTool` variants |

### Tool Categories

| Category | Examples |
|----------|----------|
| `.selection` | Select, Hand |
| `.shape` | Rectangle, Oval, Triangle |
| `.drawing` | Line, Arrow, Pencil, Highlighter |
| `.annotation` | Text, Note, Auto-number |
| `.navigation` | Hand, Zoom |

---

## Conclusion

This plugin-based architecture provides:

- **Zero code changes** to add new tools (for existing object types)
- **Tool-agnostic** CanvasView (no hardcoded logic)
- **Optional toolbar** (apps choose their own UI)
- **Clean separation** (framework vs. app layer)
- **Independently testable** tools
- **Runtime extensible** (third-party tools)

The migration can be done incrementally without breaking existing functionality, and the resulting codebase will be significantly more maintainable and reusable.
