# Annotation Tools Architecture Design

## Overview

This document outlines the architecture for extending the existing canvas application with comprehensive annotation tools. The design maintains compatibility with existing patterns while introducing new capabilities for multi-selection, canvas pan/zoom, and diverse annotation types.

---

## Table of Contents

1. [Current State Analysis](#current-state-analysis)
2. [Proposed Architecture Changes](#proposed-architecture-changes)
3. [Data Models](#data-models)
4. [Tool System](#tool-system)
5. [Selection System](#selection-system)
6. [Canvas Viewport System](#canvas-viewport-system)
7. [View Components](#view-components)
8. [Gesture Handling](#gesture-handling)
9. [Implementation Phases](#implementation-phases)

---

## 1. Current State Analysis

### Existing Capabilities
- Single-selection only
- Four tools: Select, Text, Rectangle, Circle
- Basic hit testing
- Text editing in shapes
- Drag-to-create shapes
- Color and font size customization

### Gaps to Address
- No multi-selection (Shift+Click)
- No marquee selection (drag-to-select region)
- No resize/rotate transforms
- No canvas pan/zoom (viewport)
- Limited tool variety
- No stroke styles (dashed, dotted)
- No line/arrow tools
- No freehand drawing
- No auto-numbering
- No sticker/image support

---

## 2. Proposed Architecture Changes

### 2.1 Unified Object Model

Replace separate arrays with a unified object system using protocol-based polymorphism:

```swift
// Base protocol for all canvas objects
protocol CanvasObject: Identifiable {
    var id: UUID { get }
    var position: CGPoint { get set }
    var size: CGSize { get set }
    var rotation: CGFloat { get set }  // NEW: rotation in radians
    var isLocked: Bool { get set }     // NEW: prevent editing
    var zIndex: Int { get set }        // NEW: explicit z-ordering

    func contains(_ point: CGPoint) -> Bool
    func boundingBox() -> CGRect
    func hitTest(_ point: CGPoint, threshold: CGFloat) -> HitTestResult?
}

// Objects that support text content
protocol TextContentObject: CanvasObject {
    var text: String { get set }
    var textAttributes: TextAttributes { get set }
    var isEditing: Bool { get set }
}

// Objects that support stroke styling
protocol StrokableObject: CanvasObject {
    var strokeColor: Color { get set }
    var strokeWidth: CGFloat { get set }
    var strokeStyle: StrokeStyle { get set }
}

// Objects that support fill
protocol FillableObject: CanvasObject {
    var fillColor: Color { get set }
    var fillOpacity: CGFloat { get set }
}

// Type-erased wrapper for heterogeneous storage
struct AnyCanvasObject: Identifiable {
    let id: UUID
    private let _object: any CanvasObject

    var object: any CanvasObject { _object }

    init<T: CanvasObject>(_ object: T) {
        self.id = object.id
        self._object = object
    }
}
```

### 2.2 State Architecture

```
CanvasViewModel (@MainActor, ObservableObject)
├── Objects
│   └── objects: [AnyCanvasObject]  // Unified object storage
│
├── Selection State
│   ├── selectedIds: Set<UUID>       // Multi-selection support
│   └── editingId: UUID?             // Single object in edit mode
│
├── Tool State
│   ├── activeTool: AnnotationTool
│   ├── toolSettings: ToolSettings   // Per-tool configuration
│   └── autoNumberCounter: Int       // For auto-number tool
│
├── Viewport State
│   ├── viewportOffset: CGPoint      // Pan offset
│   ├── viewportScale: CGFloat       // Zoom level (1.0 = 100%)
│   └── viewportBounds: CGRect       // Visible area
│
├── Interaction State
│   ├── interactionMode: InteractionMode
│   ├── dragState: DragState?
│   └── hoverState: HoverState?
│
└── History (Future)
    ├── undoStack: [CanvasAction]
    └── redoStack: [CanvasAction]
```

---

## 3. Data Models

### 3.1 Common Types

```swift
// Stroke styling
enum StrokeStyle: Codable, Hashable {
    case solid
    case dashed(pattern: [CGFloat])  // e.g., [5, 3] for 5pt dash, 3pt gap
    case dotted                       // Implemented as [1, 3]

    var dashPattern: [CGFloat] {
        switch self {
        case .solid: return []
        case .dashed(let pattern): return pattern
        case .dotted: return [2, 4]
        }
    }
}

// Text formatting
struct TextAttributes: Codable, Hashable {
    var fontFamily: String = "System"
    var fontSize: CGFloat = 16
    var fontWeight: Font.Weight = .regular
    var isItalic: Bool = false
    var textColor: Color = .black
    var horizontalAlignment: HorizontalAlignment = .center
    var verticalAlignment: VerticalAlignment = .center
}

// Hit test results for precise interaction
enum HitTestResult {
    case body                          // Interior of object
    case edge(Edge)                    // Edge for resize
    case corner(Corner)                // Corner for resize
    case rotationHandle                // Outside corner for rotation
    case controlPoint(index: Int)      // For lines/paths
    case label                         // For line labels
}

enum Corner: CaseIterable {
    case topLeft, topRight, bottomLeft, bottomRight
}

enum Edge: CaseIterable {
    case top, right, bottom, left
}
```

### 3.2 Shape Objects

```swift
// Rectangle shape (existing, enhanced)
struct RectangleObject: CanvasObject, TextContentObject, StrokableObject, FillableObject {
    let id: UUID
    var position: CGPoint
    var size: CGSize
    var rotation: CGFloat = 0
    var isLocked: Bool = false
    var zIndex: Int = 0

    // Stroke
    var strokeColor: Color = .black
    var strokeWidth: CGFloat = 2
    var strokeStyle: StrokeStyle = .solid

    // Fill
    var fillColor: Color = .blue
    var fillOpacity: CGFloat = 0.1

    // Text
    var text: String = ""
    var textAttributes: TextAttributes = TextAttributes()
    var isEditing: Bool = false
    var autoResizeHeight: Bool = true

    // Corner radius (NEW)
    var cornerRadius: CGFloat = 0
}

// Circle/Ellipse shape (existing, enhanced)
struct CircleObject: CanvasObject, TextContentObject, StrokableObject, FillableObject {
    // Similar to RectangleObject
    // Hit testing uses ellipse equation
}

// Generic shape for predefined shapes
struct ShapeObject: CanvasObject, TextContentObject, StrokableObject, FillableObject {
    let id: UUID
    var shapeType: ShapeType
    var position: CGPoint
    var size: CGSize
    var rotation: CGFloat = 0
    // ... other properties

    enum ShapeType: String, CaseIterable {
        case rectangle
        case roundedRectangle
        case circle
        case ellipse
        case triangle
        case diamond
        case pentagon
        case hexagon
        case star
        case arrow
        case callout
        case cloud
    }
}
```

### 3.3 Line Objects

```swift
struct LineObject: CanvasObject, StrokableObject {
    let id: UUID
    var startPoint: CGPoint
    var endPoint: CGPoint
    var rotation: CGFloat = 0
    var isLocked: Bool = false
    var zIndex: Int = 0

    // Stroke
    var strokeColor: Color = .black
    var strokeWidth: CGFloat = 2
    var strokeStyle: StrokeStyle = .solid

    // Label (NEW)
    var label: String = ""
    var labelAttributes: TextAttributes = TextAttributes()
    var isEditingLabel: Bool = false

    // Computed properties
    var position: CGPoint {
        CGPoint(x: min(startPoint.x, endPoint.x),
                y: min(startPoint.y, endPoint.y))
    }

    var size: CGSize {
        CGSize(width: abs(endPoint.x - startPoint.x),
               height: abs(endPoint.y - startPoint.y))
    }

    var midPoint: CGPoint {
        CGPoint(x: (startPoint.x + endPoint.x) / 2,
                y: (startPoint.y + endPoint.y) / 2)
    }

    func hitTest(_ point: CGPoint, threshold: CGFloat = 8) -> HitTestResult? {
        // Check control points first
        if distance(point, startPoint) < threshold { return .controlPoint(index: 0) }
        if distance(point, endPoint) < threshold { return .controlPoint(index: 1) }

        // Check label area
        if !label.isEmpty && labelBounds().contains(point) { return .label }

        // Check line proximity using point-to-line-segment distance
        if distanceToLineSegment(point, startPoint, endPoint) < threshold {
            return .body
        }

        return nil
    }
}

struct ArrowObject: CanvasObject, StrokableObject {
    let id: UUID
    var startPoint: CGPoint
    var endPoint: CGPoint
    var rotation: CGFloat = 0
    var isLocked: Bool = false
    var zIndex: Int = 0

    // Stroke
    var strokeColor: Color = .black
    var strokeWidth: CGFloat = 2
    var strokeStyle: StrokeStyle = .solid

    // Arrow heads
    var startArrowHead: ArrowHead = .none
    var endArrowHead: ArrowHead = .filled

    // Label
    var label: String = ""
    var labelAttributes: TextAttributes = TextAttributes()
    var isEditingLabel: Bool = false

    enum ArrowHead: String, CaseIterable {
        case none
        case open      // Simple V shape
        case filled    // Filled triangle
        case circle    // Circle endpoint
        case diamond   // Diamond shape
    }
}
```

### 3.4 Freehand Objects

```swift
struct PencilObject: CanvasObject, StrokableObject {
    let id: UUID
    var points: [CGPoint]           // Raw points from drawing
    var smoothedPath: Path?         // Cached smoothed path
    var rotation: CGFloat = 0
    var isLocked: Bool = false
    var zIndex: Int = 0

    // Stroke
    var strokeColor: Color = .black
    var strokeWidth: CGFloat = 2
    var strokeStyle: StrokeStyle = .solid

    // Computed bounding box
    var position: CGPoint {
        guard let minX = points.map({ $0.x }).min(),
              let minY = points.map({ $0.y }).min() else {
            return .zero
        }
        return CGPoint(x: minX, y: minY)
    }

    var size: CGSize {
        guard let minX = points.map({ $0.x }).min(),
              let maxX = points.map({ $0.x }).max(),
              let minY = points.map({ $0.y }).min(),
              let maxY = points.map({ $0.y }).max() else {
            return .zero
        }
        return CGSize(width: maxX - minX, height: maxY - minY)
    }

    // Smoothing algorithm: Catmull-Rom spline
    mutating func smoothPath() {
        guard points.count > 2 else { return }
        smoothedPath = catmullRomSpline(points: points)
    }
}

struct HighlighterObject: CanvasObject, StrokableObject {
    let id: UUID
    var points: [CGPoint]
    var smoothedPath: Path?
    var rotation: CGFloat = 0
    var isLocked: Bool = false
    var zIndex: Int = 0

    // Stroke (defaults for highlighter)
    var strokeColor: Color = .yellow
    var strokeWidth: CGFloat = 20      // Thicker
    var strokeOpacity: CGFloat = 0.4   // Semi-transparent
    var strokeStyle: StrokeStyle = .solid

    // Line cap for rounded ends
    var lineCap: CGLineCap = .round
}
```

### 3.5 Special Objects

```swift
struct TextObject: CanvasObject, TextContentObject {
    let id: UUID
    var position: CGPoint
    var size: CGSize                   // Calculated from text
    var rotation: CGFloat = 0
    var isLocked: Bool = false
    var zIndex: Int = 0

    var text: String
    var textAttributes: TextAttributes
    var isEditing: Bool = false

    var maxWidth: CGFloat = 200        // Default max width, fit to content after commit
}

struct NoteObject: CanvasObject, TextContentObject, FillableObject {
    let id: UUID
    var position: CGPoint
    var size: CGSize
    var rotation: CGFloat = 0
    var isLocked: Bool = false
    var zIndex: Int = 0

    // Fill (no stroke for notes)
    var fillColor: Color = .yellow
    var fillOpacity: CGFloat = 1.0

    // Text
    var text: String = ""
    var textAttributes: TextAttributes = TextAttributes()
    var isEditing: Bool = false
}

struct AutoNumberObject: CanvasObject, TextContentObject, StrokableObject, FillableObject {
    let id: UUID
    var position: CGPoint             // Center position
    var radius: CGFloat = 20          // Circle radius
    var rotation: CGFloat = 0
    var isLocked: Bool = false
    var zIndex: Int = 0

    // Number
    var number: Int
    var textAttributes: TextAttributes = TextAttributes()
    var isEditing: Bool = false       // Not typically editable

    // Stroke & Fill
    var strokeColor: Color = .blue
    var strokeWidth: CGFloat = 2
    var strokeStyle: StrokeStyle = .solid
    var fillColor: Color = .white
    var fillOpacity: CGFloat = 1.0

    var text: String { "\(number)" }
    var size: CGSize { CGSize(width: radius * 2, height: radius * 2) }
}

struct StickerObject: CanvasObject {
    let id: UUID
    var position: CGPoint
    var size: CGSize
    var rotation: CGFloat = 0
    var isLocked: Bool = false
    var zIndex: Int = 0

    var stickerName: String           // Reference to asset
    var stickerImage: NSImage?        // Cached image
}

struct ImageObject: CanvasObject {
    let id: UUID
    var position: CGPoint
    var size: CGSize
    var rotation: CGFloat = 0
    var isLocked: Bool = false
    var zIndex: Int = 0

    var imagePath: URL?               // Local file reference
    var imageData: Data?              // Embedded image data
    var aspectRatio: CGFloat          // Original aspect ratio
    var maintainAspectRatio: Bool = true
}

struct MosaicObject: CanvasObject {
    let id: UUID
    var position: CGPoint
    var size: CGSize
    var rotation: CGFloat = 0
    var isLocked: Bool = false
    var zIndex: Int = 0

    var blurRadius: CGFloat = 10      // Blur intensity
    var mosaicType: MosaicType = .blur

    enum MosaicType {
        case blur                      // Gaussian blur
        case pixelate                  // Pixelation effect
    }
}
```

---

## 4. Tool System

### 4.1 Tool Definition

```swift
enum AnnotationTool: String, CaseIterable, Identifiable {
    case select
    case hand
    case shape
    case line
    case arrow
    case pencil
    case highlighter
    case mosaic
    case text
    case autoNumber
    case sticker
    case note
    case image

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .select: return "arrow.up.left.and.arrow.down.right"
        case .hand: return "hand.raised"
        case .shape: return "square.on.circle"
        case .line: return "line.diagonal"
        case .arrow: return "arrow.right"
        case .pencil: return "pencil"
        case .highlighter: return "highlighter"
        case .mosaic: return "square.grid.3x3"
        case .text: return "textformat"
        case .autoNumber: return "number.circle"
        case .sticker: return "face.smiling"
        case .note: return "note.text"
        case .image: return "photo"
        }
    }

    var cursor: NSCursor {
        switch self {
        case .select: return .arrow
        case .hand: return .openHand
        case .text: return .iBeam
        default: return .crosshair
        }
    }
}
```

### 4.2 Tool Settings

```swift
struct ToolSettings: ObservableObject {
    // Shape tool
    @Published var selectedShape: ShapeObject.ShapeType = .rectangle

    // Common stroke settings
    @Published var strokeColor: Color = .black
    @Published var strokeWidth: CGFloat = 2
    @Published var strokeStyle: StrokeStyle = .solid

    // Common fill settings
    @Published var fillColor: Color = .blue
    @Published var fillOpacity: CGFloat = 0.1

    // Text settings
    @Published var textAttributes: TextAttributes = TextAttributes()

    // Auto-number
    @Published var autoNumberCounter: Int = 1
    @Published var autoNumberColor: Color = .blue

    // Sticker
    @Published var selectedSticker: String = "star"

    // Highlighter
    @Published var highlighterColor: Color = .yellow
    @Published var highlighterOpacity: CGFloat = 0.4

    // Mosaic
    @Published var mosaicType: MosaicObject.MosaicType = .blur
    @Published var mosaicIntensity: CGFloat = 10

    func resetAutoNumber() {
        autoNumberCounter = 1
    }
}
```

---

## 5. Selection System

### 5.1 Selection State

```swift
struct SelectionState {
    var selectedIds: Set<UUID> = []
    var editingId: UUID?

    var isEmpty: Bool { selectedIds.isEmpty }
    var count: Int { selectedIds.count }
    var isSingleSelection: Bool { selectedIds.count == 1 }
    var isMultiSelection: Bool { selectedIds.count > 1 }

    mutating func select(_ id: UUID, additive: Bool = false) {
        if additive {
            if selectedIds.contains(id) {
                selectedIds.remove(id)
            } else {
                selectedIds.insert(id)
            }
        } else {
            selectedIds = [id]
        }
        editingId = nil
    }

    mutating func selectMultiple(_ ids: Set<UUID>) {
        selectedIds = ids
        editingId = nil
    }

    mutating func deselectAll() {
        selectedIds.removeAll()
        editingId = nil
    }

    mutating func startEditing(_ id: UUID) {
        selectedIds = [id]
        editingId = id
    }

    mutating func stopEditing() {
        editingId = nil
    }
}
```

### 5.2 Selection Box

```swift
struct SelectionBox {
    let bounds: CGRect                 // Combined bounds of all selected objects
    let individualBounds: [UUID: CGRect]  // Per-object bounds for transforms
    let center: CGPoint
    let rotation: CGFloat              // Only for single selection

    // Hit test zones
    func hitTest(_ point: CGPoint) -> SelectionHitZone? {
        let handleSize: CGFloat = 8
        let rotationOffset: CGFloat = 20

        // Check rotation handles (outside corners)
        for corner in Corner.allCases {
            let handlePos = rotationHandlePosition(for: corner)
            if distance(point, handlePos) < handleSize + rotationOffset {
                return .rotation(corner)
            }
        }

        // Check resize corners
        for corner in Corner.allCases {
            let handlePos = cornerHandlePosition(for: corner)
            if distance(point, handlePos) < handleSize {
                return .corner(corner)
            }
        }

        // Check resize edges
        for edge in Edge.allCases {
            if edgeHitTest(point, edge: edge, threshold: handleSize) {
                return .edge(edge)
            }
        }

        // Check interior for move
        if bounds.contains(point) {
            return .move
        }

        return nil
    }
}

enum SelectionHitZone {
    case move
    case corner(Corner)
    case edge(Edge)
    case rotation(Corner)
}
```

### 5.3 Marquee Selection

```swift
struct MarqueeSelection {
    var startPoint: CGPoint
    var currentPoint: CGPoint

    var rect: CGRect {
        CGRect(
            x: min(startPoint.x, currentPoint.x),
            y: min(startPoint.y, currentPoint.y),
            width: abs(currentPoint.x - startPoint.x),
            height: abs(currentPoint.y - startPoint.y)
        )
    }

    func selectsObject(_ object: any CanvasObject) -> Bool {
        rect.intersects(object.boundingBox())
    }
}
```

---

## 6. Canvas Viewport System

### 6.1 Viewport State

```swift
struct ViewportState {
    var offset: CGPoint = .zero        // Pan offset
    var scale: CGFloat = 1.0           // Zoom level

    let minScale: CGFloat = 0.1
    let maxScale: CGFloat = 10.0

    // Convert screen coordinates to canvas coordinates
    func canvasPoint(from screenPoint: CGPoint, canvasSize: CGSize) -> CGPoint {
        CGPoint(
            x: (screenPoint.x - offset.x) / scale,
            y: (screenPoint.y - offset.y) / scale
        )
    }

    // Convert canvas coordinates to screen coordinates
    func screenPoint(from canvasPoint: CGPoint) -> CGPoint {
        CGPoint(
            x: canvasPoint.x * scale + offset.x,
            y: canvasPoint.y * scale + offset.y
        )
    }

    // Zoom centered on a point
    mutating func zoom(by factor: CGFloat, centeredOn point: CGPoint) {
        let newScale = (scale * factor).clamped(to: minScale...maxScale)
        let scaleDiff = newScale / scale

        offset.x = point.x - (point.x - offset.x) * scaleDiff
        offset.y = point.y - (point.y - offset.y) * scaleDiff
        scale = newScale
    }

    // Pan by delta
    mutating func pan(by delta: CGPoint) {
        offset.x += delta.x
        offset.y += delta.y
    }

    // Reset to default
    mutating func reset() {
        offset = .zero
        scale = 1.0
    }

    // Fit content in view
    mutating func fitContent(_ contentBounds: CGRect, in viewSize: CGSize, padding: CGFloat = 50) {
        let scaleX = (viewSize.width - padding * 2) / contentBounds.width
        let scaleY = (viewSize.height - padding * 2) / contentBounds.height
        scale = min(scaleX, scaleY, 1.0).clamped(to: minScale...maxScale)

        offset = CGPoint(
            x: (viewSize.width - contentBounds.width * scale) / 2 - contentBounds.origin.x * scale,
            y: (viewSize.height - contentBounds.height * scale) / 2 - contentBounds.origin.y * scale
        )
    }
}
```

### 6.2 Gesture Handling for Viewport

```swift
// Two-finger pan (trackpad) - works with all tools
// This is handled via NSResponder or magnification gesture

extension CanvasView {
    func handleMagnification(_ gesture: MagnificationGesture.Value) {
        viewModel.viewport.zoom(by: gesture.magnification, centeredOn: gestureCenter)
    }

    func handleTwoFingerPan(_ delta: CGPoint) {
        viewModel.viewport.pan(by: delta)
    }
}

// Hand tool specific - single finger/mouse drag pans
func handleHandToolDrag(_ value: DragGesture.Value) {
    let delta = CGPoint(
        x: value.translation.width - (lastDragTranslation?.width ?? 0),
        y: value.translation.height - (lastDragTranslation?.height ?? 0)
    )
    viewModel.viewport.pan(by: delta)
    lastDragTranslation = value.translation
}
```

---

## 7. View Components

### 7.1 View Hierarchy

```
ContentView
├── VStack
│   ├── ToolbarView
│   │   ├── ToolPicker (segmented/grid)
│   │   ├── ToolSettingsView (context-sensitive)
│   │   └── ViewportControls (zoom slider, fit, reset)
│   │
│   └── CanvasContainerView
│       ├── GeometryReader
│       │   └── CanvasView
│       │       ├── ZStack (transformed by viewport)
│       │       │   ├── CanvasBackground
│       │       │   │   └── DotGrid (scaled with viewport)
│       │       │   │
│       │       │   ├── ObjectsLayer
│       │       │   │   └── ForEach(objects sorted by zIndex)
│       │       │   │       └── ObjectView (type-specific)
│       │       │   │
│       │       │   ├── SelectionOverlay
│       │       │   │   ├── SelectionBox (single)
│       │       │   │   │   ├── Border
│       │       │   │   │   ├── CornerHandles
│       │       │   │   │   └── RotationHandles
│       │       │   │   └── MultiSelectionBox
│       │       │   │       └── Combined bounds indicator
│       │       │   │
│       │       │   ├── MarqueeOverlay (during drag-select)
│       │       │   └── DragPreviewOverlay (during creation)
│       │       │
│       │       └── GestureLayer (transparent, captures all input)
│       │
│       └── FloatingPanels
│           ├── FormatBar (when editing text)
│           └── ShapePickerPopover (when shape tool active)
```

### 7.2 Object View Factory

```swift
struct ObjectViewFactory {
    @ViewBuilder
    static func view(for object: AnyCanvasObject,
                     viewModel: CanvasViewModel,
                     isSelected: Bool) -> some View {
        switch object.object {
        case let rect as RectangleObject:
            RectangleObjectView(object: rect, viewModel: viewModel, isSelected: isSelected)

        case let circle as CircleObject:
            CircleObjectView(object: circle, viewModel: viewModel, isSelected: isSelected)

        case let text as TextObject:
            TextObjectView(object: text, viewModel: viewModel, isSelected: isSelected)

        case let line as LineObject:
            LineObjectView(object: line, viewModel: viewModel, isSelected: isSelected)

        case let arrow as ArrowObject:
            ArrowObjectView(object: arrow, viewModel: viewModel, isSelected: isSelected)

        case let pencil as PencilObject:
            PencilObjectView(object: pencil, viewModel: viewModel, isSelected: isSelected)

        case let highlighter as HighlighterObject:
            HighlighterObjectView(object: highlighter, viewModel: viewModel, isSelected: isSelected)

        case let autoNum as AutoNumberObject:
            AutoNumberObjectView(object: autoNum, viewModel: viewModel, isSelected: isSelected)

        case let sticker as StickerObject:
            StickerObjectView(object: sticker, viewModel: viewModel, isSelected: isSelected)

        case let note as NoteObject:
            NoteObjectView(object: note, viewModel: viewModel, isSelected: isSelected)

        case let image as ImageObject:
            ImageObjectView(object: image, viewModel: viewModel, isSelected: isSelected)

        case let mosaic as MosaicObject:
            MosaicObjectView(object: mosaic, viewModel: viewModel, isSelected: isSelected)

        default:
            EmptyView()
        }
    }
}
```

### 7.3 Selection Box View

```swift
struct SelectionBoxView: View {
    let selectionBox: SelectionBox
    let isSingleSelection: Bool
    @ObservedObject var viewModel: CanvasViewModel

    private let handleSize: CGFloat = 8
    private let strokeColor = Color.blue

    var body: some View {
        ZStack {
            // Selection rectangle
            Rectangle()
                .stroke(strokeColor, lineWidth: 1)
                .frame(width: selectionBox.bounds.width,
                       height: selectionBox.bounds.height)

            // Corner handles (resize)
            ForEach(Corner.allCases, id: \.self) { corner in
                ResizeHandle(corner: corner, size: handleSize)
                    .position(cornerPosition(corner))
                    .onHover { hovering in
                        if hovering {
                            NSCursor.resize(for: corner).set()
                        }
                    }
            }

            // Edge handles (resize) - shown only for single selection
            if isSingleSelection {
                ForEach(Edge.allCases, id: \.self) { edge in
                    EdgeHandle(edge: edge, size: handleSize)
                        .position(edgePosition(edge))
                        .onHover { hovering in
                            if hovering {
                                NSCursor.resize(for: edge).set()
                            }
                        }
                }
            }

            // Rotation handles (outside corners) - shown only for single selection
            if isSingleSelection {
                ForEach(Corner.allCases, id: \.self) { corner in
                    RotationHandle(size: handleSize)
                        .position(rotationHandlePosition(corner))
                        .onHover { hovering in
                            if hovering {
                                NSCursor.rotation.set()
                            }
                        }
                }
            }
        }
        .position(x: selectionBox.bounds.midX, y: selectionBox.bounds.midY)
        .rotationEffect(.radians(isSingleSelection ? selectionBox.rotation : 0))
    }
}
```

---

## 8. Gesture Handling

### 8.1 Interaction State Machine

```swift
enum InteractionMode {
    case idle
    case dragging(DragContext)
    case drawing(DrawingContext)
    case selecting(MarqueeContext)
    case panning
    case editing(UUID)
}

struct DragContext {
    let startPoint: CGPoint
    let objectIds: Set<UUID>
    let initialPositions: [UUID: CGPoint]
    var currentPoint: CGPoint
}

struct DrawingContext {
    let tool: AnnotationTool
    let startPoint: CGPoint
    var currentPoint: CGPoint
    var points: [CGPoint]  // For freehand tools
}

struct MarqueeContext {
    let startPoint: CGPoint
    var currentPoint: CGPoint
    let additive: Bool  // Shift was held
}
```

### 8.2 Gesture Coordinator

```swift
class GestureCoordinator {
    private var viewModel: CanvasViewModel
    private var interactionMode: InteractionMode = .idle
    private var lastTapTime: Date?
    private var lastTapLocation: CGPoint?

    // Constants
    private let clickThreshold: CGFloat = 5
    private let doubleClickTimeThreshold: TimeInterval = 0.3
    private let doubleClickDistanceThreshold: CGFloat = 10

    func handleDragStart(_ value: DragGesture.Value, shiftHeld: Bool) {
        let canvasPoint = viewModel.viewport.canvasPoint(from: value.startLocation,
                                                          canvasSize: viewModel.canvasSize)

        switch viewModel.activeTool {
        case .select:
            handleSelectToolDragStart(canvasPoint, shiftHeld: shiftHeld)

        case .hand:
            interactionMode = .panning

        case .shape, .line, .arrow, .mosaic:
            interactionMode = .drawing(DrawingContext(
                tool: viewModel.activeTool,
                startPoint: canvasPoint,
                currentPoint: canvasPoint,
                points: [canvasPoint]
            ))

        case .pencil, .highlighter:
            interactionMode = .drawing(DrawingContext(
                tool: viewModel.activeTool,
                startPoint: canvasPoint,
                currentPoint: canvasPoint,
                points: [canvasPoint]
            ))

        case .text, .autoNumber, .sticker, .note:
            // These are click-to-place, handle in dragEnd
            break

        case .image:
            // Opens file picker
            break
        }
    }

    func handleDragChanged(_ value: DragGesture.Value) {
        let canvasPoint = viewModel.viewport.canvasPoint(from: value.location,
                                                          canvasSize: viewModel.canvasSize)

        switch interactionMode {
        case .dragging(var context):
            context.currentPoint = canvasPoint
            interactionMode = .dragging(context)
            updateObjectPositions(context)

        case .drawing(var context):
            context.currentPoint = canvasPoint
            if viewModel.activeTool == .pencil || viewModel.activeTool == .highlighter {
                context.points.append(canvasPoint)
            }
            interactionMode = .drawing(context)
            viewModel.updateDrawingPreview(context)

        case .selecting(var context):
            context.currentPoint = canvasPoint
            interactionMode = .selecting(context)
            viewModel.updateMarqueeSelection(context)

        case .panning:
            viewModel.viewport.pan(by: CGPoint(
                x: value.translation.width - (lastPanTranslation?.width ?? 0),
                y: value.translation.height - (lastPanTranslation?.height ?? 0)
            ))
            lastPanTranslation = value.translation

        default:
            break
        }
    }

    func handleDragEnd(_ value: DragGesture.Value, shiftHeld: Bool) {
        let canvasPoint = viewModel.viewport.canvasPoint(from: value.location,
                                                          canvasSize: viewModel.canvasSize)
        let distance = hypot(value.translation.width, value.translation.height)
        let isClick = distance < clickThreshold

        switch viewModel.activeTool {
        case .select:
            if isClick {
                handleSelectToolClick(canvasPoint, shiftHeld: shiftHeld)
            } else {
                finalizeInteraction()
            }

        case .hand:
            interactionMode = .idle

        case .shape, .line, .arrow, .mosaic:
            if !isClick {
                finalizeDrawing(shiftHeld: shiftHeld)
            }

        case .pencil, .highlighter:
            if !isClick {
                finalizeFreehandDrawing()
            }

        case .text:
            if isClick {
                handleTextToolClick(canvasPoint)
            }

        case .autoNumber:
            if isClick {
                viewModel.placeAutoNumber(at: canvasPoint)
            }

        case .sticker:
            if isClick {
                viewModel.placeSticker(at: canvasPoint)
            }

        case .note:
            if isClick {
                viewModel.placeNote(at: canvasPoint)
            }

        case .image:
            if isClick {
                viewModel.showImagePicker(at: canvasPoint)
            }
        }

        interactionMode = .idle
    }

    private func handleSelectToolDragStart(_ point: CGPoint, shiftHeld: Bool) {
        // Check if clicking on selection box handles first
        if let selectionBox = viewModel.selectionBox,
           let hitZone = selectionBox.hitTest(point) {
            handleSelectionBoxInteraction(hitZone, startPoint: point)
            return
        }

        // Check if clicking on an object
        if let hitObject = viewModel.hitTest(point) {
            if shiftHeld {
                viewModel.selection.select(hitObject.id, additive: true)
            } else if !viewModel.selection.selectedIds.contains(hitObject.id) {
                viewModel.selection.select(hitObject.id, additive: false)
            }

            // Start dragging selected objects
            interactionMode = .dragging(DragContext(
                startPoint: point,
                objectIds: viewModel.selection.selectedIds,
                initialPositions: viewModel.getObjectPositions(viewModel.selection.selectedIds),
                currentPoint: point
            ))
        } else {
            // Start marquee selection
            if !shiftHeld {
                viewModel.selection.deselectAll()
            }
            interactionMode = .selecting(MarqueeContext(
                startPoint: point,
                currentPoint: point,
                additive: shiftHeld
            ))
        }
    }

    private func handleSelectToolClick(_ point: CGPoint, shiftHeld: Bool) {
        let isDoubleClick = checkDoubleClick(at: point)

        if isDoubleClick {
            // Double-click: start editing
            if let hitObject = viewModel.hitTest(point),
               hitObject is TextContentObject {
                viewModel.selection.startEditing(hitObject.id)
            }
        } else {
            // Single click: select/deselect
            if let hitObject = viewModel.hitTest(point) {
                viewModel.selection.select(hitObject.id, additive: shiftHeld)
            } else if !shiftHeld {
                viewModel.selection.deselectAll()
            }
        }

        updateTapTracking(at: point)
    }
}
```

### 8.3 Keyboard Modifiers

```swift
struct KeyboardModifiers {
    var shift: Bool = false      // Additive selection, constrain proportions
    var command: Bool = false    // Reserved for shortcuts
    var option: Bool = false     // Clone while dragging (future)
    var control: Bool = false    // Reserved
}

extension CanvasView {
    func handleKeyDown(_ event: NSEvent) {
        switch event.keyCode {
        case 56: // Shift
            viewModel.modifiers.shift = true
        case 55: // Command
            viewModel.modifiers.command = true
        case 58: // Option
            viewModel.modifiers.option = true
        default:
            break
        }
    }

    func handleKeyUp(_ event: NSEvent) {
        switch event.keyCode {
        case 56:
            viewModel.modifiers.shift = false
        case 55:
            viewModel.modifiers.command = false
        case 58:
            viewModel.modifiers.option = false
        default:
            break
        }
    }
}
```

---

## 9. Implementation Phases

### Phase 1: Foundation (Core Infrastructure)
**Goal**: Establish the new architecture without breaking existing functionality

1. **Unified Object System**
   - Create `CanvasObject` protocol hierarchy
   - Create `AnyCanvasObject` wrapper
   - Migrate existing models to conform to protocols
   - Update `CanvasViewModel` to use unified storage

2. **Enhanced Selection System**
   - Implement `SelectionState` with multi-selection
   - Add Shift+Click for additive selection
   - Implement marquee (drag-to-select) selection
   - Create `SelectionBoxView` with handles

3. **Viewport System**
   - Implement `ViewportState` with pan/zoom
   - Add two-finger trackpad gestures
   - Add zoom controls to toolbar
   - Transform canvas content by viewport

4. **Gesture Refactoring**
   - Implement `InteractionMode` state machine
   - Create `GestureCoordinator`
   - Handle keyboard modifiers

**Deliverables**: Working multi-selection, pan/zoom, same tools as before

---

### Phase 2: Selection Box Interactions
**Goal**: Full selection box manipulation

1. **Resize Functionality**
   - Corner resize (diagonal)
   - Edge resize (horizontal/vertical)
   - Shift+resize for proportional scaling
   - Multi-object resize (scale from center)

2. **Rotation Functionality**
   - Rotation handles outside corners
   - Rotation cursor feedback
   - Shift+rotate for 15° snapping
   - Single-object rotation only (initially)

3. **Cursor Feedback**
   - Resize cursors on edges/corners
   - Rotation cursor outside corners
   - Move cursor inside selection
   - Tool-specific cursors

**Deliverables**: Fully interactive selection box with resize/rotate

---

### Phase 3: New Drawing Tools
**Goal**: Add line, arrow, pencil, highlighter

1. **Line Tool**
   - Two-point line drawing
   - Stroke styles (solid, dashed, dotted)
   - Selection shows two control points
   - Double-click to add/edit label

2. **Arrow Tool**
   - Extends line tool
   - Arrow head styles (open, filled, etc.)
   - Arrow at start/end/both options

3. **Pencil Tool**
   - Freehand point collection
   - Catmull-Rom smoothing
   - Stroke customization

4. **Highlighter Tool**
   - Thick, semi-transparent stroke
   - Default yellow color
   - Optimized for annotation use

**Deliverables**: Four new drawing tools fully functional

---

### Phase 4: Special Annotation Tools
**Goal**: Add specialized annotation objects

1. **Auto-Number Tool**
   - Click to place numbered circle
   - Auto-increment counter
   - Reset counter option
   - Style customization

2. **Mosaic/Blur Tool**
   - Rectangular blur region
   - Blur vs pixelate options
   - Adjustable intensity
   - No border/text support

3. **Note Tool**
   - Colored rectangle background
   - No border
   - Text editing support
   - Default yellow color

4. **Sticker Tool**
   - Predefined sticker library
   - Click to place
   - Resize support

5. **Image Tool**
   - File picker integration
   - Aspect ratio maintenance
   - Resize support

**Deliverables**: All special annotation tools working

---

### Phase 5: Enhanced Shape Tool
**Goal**: Shape picker and advanced shape features

1. **Shape Picker UI**
   - Grid/list of predefined shapes
   - Quick access popover
   - Recently used shapes

2. **Shape Types**
   - Rectangle, rounded rectangle
   - Circle, ellipse
   - Triangle, diamond
   - Pentagon, hexagon, star
   - Callout, cloud, arrow shapes

3. **Shape Properties Panel**
   - Stroke color, width, style
   - Fill color, opacity
   - Corner radius (for applicable shapes)
   - Text alignment options

**Deliverables**: Full shape tool with variety

---

### Phase 6: Polish and Refinement
**Goal**: Production-ready quality

1. **Undo/Redo System**
   - Action-based history
   - Grouping related actions
   - Memory-efficient storage

2. **Keyboard Shortcuts**
   - Tool switching (V, H, R, L, etc.)
   - Delete, duplicate, copy/paste
   - Undo/redo (Cmd+Z, Cmd+Shift+Z)
   - Zoom controls (Cmd+/-, Cmd+0)

3. **Performance Optimization**
   - Object culling (only render visible)
   - Efficient hit testing (spatial index)
   - Smooth freehand drawing

4. **Persistence**
   - Save/load canvas state
   - Export to image formats
   - Auto-save draft

**Deliverables**: Polished, production-ready annotation tool

---

## File Structure (Proposed)

```
texttool/
├── texttool/
│   ├── texttoolApp.swift
│   ├── ContentView.swift
│   │
│   ├── Models/
│   │   ├── Protocols/
│   │   │   ├── CanvasObject.swift
│   │   │   ├── TextContentObject.swift
│   │   │   ├── StrokableObject.swift
│   │   │   └── FillableObject.swift
│   │   │
│   │   ├── Objects/
│   │   │   ├── RectangleObject.swift
│   │   │   ├── CircleObject.swift
│   │   │   ├── ShapeObject.swift
│   │   │   ├── TextObject.swift
│   │   │   ├── LineObject.swift
│   │   │   ├── ArrowObject.swift
│   │   │   ├── PencilObject.swift
│   │   │   ├── HighlighterObject.swift
│   │   │   ├── AutoNumberObject.swift
│   │   │   ├── StickerObject.swift
│   │   │   ├── NoteObject.swift
│   │   │   ├── ImageObject.swift
│   │   │   └── MosaicObject.swift
│   │   │
│   │   ├── AnyCanvasObject.swift
│   │   ├── DrawingTool.swift → AnnotationTool.swift
│   │   ├── ToolSettings.swift
│   │   ├── StrokeStyle.swift
│   │   └── TextAttributes.swift
│   │
│   ├── ViewModels/
│   │   ├── CanvasViewModel.swift
│   │   ├── SelectionState.swift
│   │   ├── ViewportState.swift
│   │   └── GestureCoordinator.swift
│   │
│   ├── Views/
│   │   ├── Canvas/
│   │   │   ├── CanvasView.swift
│   │   │   ├── CanvasBackground.swift
│   │   │   ├── ObjectsLayer.swift
│   │   │   └── OverlayLayer.swift
│   │   │
│   │   ├── Objects/
│   │   │   ├── ObjectViewFactory.swift
│   │   │   ├── RectangleObjectView.swift
│   │   │   ├── CircleObjectView.swift
│   │   │   ├── TextObjectView.swift
│   │   │   ├── LineObjectView.swift
│   │   │   ├── ArrowObjectView.swift
│   │   │   ├── PencilObjectView.swift
│   │   │   ├── HighlighterObjectView.swift
│   │   │   ├── AutoNumberObjectView.swift
│   │   │   ├── StickerObjectView.swift
│   │   │   ├── NoteObjectView.swift
│   │   │   ├── ImageObjectView.swift
│   │   │   └── MosaicObjectView.swift
│   │   │
│   │   ├── Selection/
│   │   │   ├── SelectionBoxView.swift
│   │   │   ├── ResizeHandle.swift
│   │   │   ├── RotationHandle.swift
│   │   │   └── MarqueeView.swift
│   │   │
│   │   ├── Toolbar/
│   │   │   ├── ToolbarView.swift
│   │   │   ├── ToolPicker.swift
│   │   │   ├── ToolSettingsView.swift
│   │   │   ├── ShapePicker.swift
│   │   │   ├── StickerPicker.swift
│   │   │   └── ViewportControls.swift
│   │   │
│   │   ├── Panels/
│   │   │   ├── FloatingFormatBar.swift
│   │   │   └── PropertiesPanel.swift
│   │   │
│   │   └── Common/
│   │       ├── AutoGrowingTextView.swift
│   │       └── ColorPickerButton.swift
│   │
│   ├── Utilities/
│   │   ├── GeometryHelpers.swift
│   │   ├── PathSmoothing.swift
│   │   ├── HitTesting.swift
│   │   └── CursorManager.swift
│   │
│   └── Assets.xcassets/
│       ├── Stickers/
│       └── Icons/
│
└── texttoolTests/
    ├── Models/
    ├── ViewModels/
    └── Utilities/
```

---

## Summary

This architecture design provides a comprehensive plan for building annotation tools with:

1. **Unified object model** using protocols for flexible, type-safe object handling
2. **Multi-selection support** with Shift+Click and marquee selection
3. **Full transform capabilities** including resize and rotation
4. **Canvas viewport** with pan/zoom for large documents
5. **12 annotation tools** covering shapes, lines, freehand, and special annotations
6. **Extensible design** allowing easy addition of new tools and features
7. **Phased implementation** to deliver value incrementally while maintaining stability

The design preserves existing functionality while providing a clear migration path to the enhanced architecture.
