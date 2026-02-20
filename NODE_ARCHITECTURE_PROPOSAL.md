# Node-Based Architecture Proposal for TextTool Canvas

## Executive Summary

This document analyzes node-based architecture patterns from industry-leading canvas libraries (Konva.js, Fabric.js, React Flow, tldraw, Excalidraw) and provides specific guidance for implementing **lines and arrows** in TextTool.

**Key Decision**: Lines/arrows should be implemented as **independent node objects** (Phase 1), with an optional binding system for connections (Phase 2, future) if diagram features are needed. This hybrid approach is proven by tldraw and Excalidraw.

**Status**: Your codebase already implements the core node architecture. This document focuses on the **specific design decision for line/arrow tools** and provides a roadmap for optional scene graph enhancements.

## Table of Contents

1. [Current State Analysis](#current-state-analysis)
2. [Critical Question: Lines/Arrows as Nodes or Edges?](#critical-question-linesarrows-as-nodes-or-edges)
3. [Industry Pattern Analysis](#industry-patterns-analysis)
4. [Recommended Approach for TextTool](#recommended-approach-for-texttool)
5. [Implementation Roadmap](#implementation-roadmap)
6. [Optional Scene Graph Enhancements](#optional-scene-graph-enhancements)

---

## Current State Analysis

### Existing Architecture ✅

Your codebase has **already implemented** the core node-based architecture:

1. ✅ **Unified Object Protocol**: `CanvasObject` protocol with common properties (id, position, size, rotation, zIndex)
2. ✅ **Type Erasure**: `AnyCanvasObject` wrapper for heterogeneous collections
3. ✅ **Protocol Composition**: `TextContentObject`, `StrokableObject`, `FillableObject` for capabilities
4. ✅ **Single Storage**: `objects: [AnyCanvasObject]` array in `CanvasViewModel`
5. ✅ **Hit Testing**: Detailed hit test system with edge/corner/body detection
6. ✅ **Z-Index Management**: Explicit rendering order
7. ✅ **Multi-Selection**: Selection system with Shift+Click and marquee
8. ✅ **Viewport System**: Pan/zoom with trackpad gestures
9. ✅ **Transform System**: Resize/rotate via selection box handles

**Conclusion**: You have a **production-ready node architecture**. The question is how to handle lines/arrows specifically.

### Optional Future Enhancements

These are **not required** for basic functionality, but could improve performance and organization:

1. **Parent-Child Relationships**: Hierarchical grouping for complex compositions
2. **Transform Inheritance**: Automatic propagation of transforms to children
3. **Scene Graph Tree**: Nested structure instead of flat array
4. **Spatial Indexing**: QuadTree for O(log n) hit testing at scale (50+ objects)
5. **Dirty Region Tracking**: Partial redraws for performance
6. **Connection System**: Semantic relationships between objects (only if diagram features needed)

**Decision Point**: Only implement these if performance/complexity demands it.

---

## Critical Question: Lines/Arrows as Nodes or Edges?

This is the **key architectural decision** for TextTool's next phase.

---

## Industry Patterns Analysis

**How do leading canvas libraries handle lines and arrows?**

### 1. Konva.js Scene Graph Pattern

**Key Concepts:**
- **Stage → Layer → Group → Shape** hierarchy
- Child transforms inherit from parents automatically
- Separate "hit graph" canvas for fast event detection
- Dirty region detection for partial redraws

**Architecture:**
```
Stage (root container)
├── Layer (rendering context)
│   ├── Group (transform container)
│   │   ├── Shape (visual element)
│   │   └── Shape
│   └── Group
│       └── Shape
└── Layer
    └── Shape
```

**Benefits:**
- Automatic coordinate transformation propagation
- Efficient event bubbling up the hierarchy
- Layer-based rendering optimization
- Natural grouping for multi-selection

**Source:** [Konva Framework Overview](https://konvajs.org/docs/overview.html), [Getting started with React and Konva](https://konvajs.org/docs/react/index.html)

### 2. Fabric.js Object-Oriented Pattern

**Key Concepts:**
- All elements inherit from `fabric.Object` base class
- Canvas maintains flat object collection with spatial indexing
- Individual object event listeners (not global)
- Built-in serialization/deserialization

**Architecture:**
```swift
// Fabric.js equivalent pattern
protocol FabricObject {
    var canvas: Canvas? { get set }
    func render(context: CGContext)
    func contains(point: CGPoint) -> Bool
    func toJSON() -> [String: Any]
}

class Canvas {
    var objects: [FabricObject]
    var activeObject: FabricObject?
    var activeGroup: Group?
}
```

**Benefits:**
- Simple flat structure for basic use cases
- Strong serialization support
- Flexible event model

**Source:** [Fabric.js vs Konva Comparison](https://stackshare.io/stackups/fabricjs-vs-konva), [How I choose Fabric.js again](https://0ro.github.io/posts/how-i-choose-fabricjs-again/)

### 3. React Flow Node Graph Pattern

**Key Concepts:**
- Nodes and edges as first-class entities
- JSON-based state representation
- Connection points (handles) on nodes
- Viewport transformation for pan/zoom

**Data Structure:**
```typescript
type Node = {
  id: string
  type: string
  position: { x: number, y: number }
  data: any  // custom node data
  parentNode?: string  // for hierarchical grouping
}

type Edge = {
  id: string
  source: string      // source node ID
  target: string      // target node ID
  sourceHandle?: string
  targetHandle?: string
}
```

**Benefits:**
- Clear node-edge separation
- Natural for diagram/flow applications
- Easy serialization to JSON
- Built-in connection management

**Source:** [React Flow Examples](https://reactflow.dev/examples), [React Flow Blog](https://medium.com/react-digital-garden/react-flow-examples-2cbb0bab4404)

### 4. tldraw Hybrid Pattern ⭐ **RECOMMENDED**

**Key Concepts:**
- Arrows are independent shapes with optional binding to other shapes
- No binding = manual positioning (annotation use case)
- With binding = auto-update when shapes move (diagram use case)
- Binding can be toggled on/off per arrow

**Architecture:**
```typescript
type Arrow = {
  id: string
  type: 'arrow'
  startPoint: { x: number, y: number }
  endPoint: { x: number, y: number }

  // Optional binding
  binding?: {
    sourceShapeId?: string
    targetShapeId?: string
    sourceAnchor: AnchorPoint
    targetAnchor: AnchorPoint
  }
}

// Effective points computed at render time
function getEffectiveStartPoint(arrow: Arrow) {
  if (arrow.binding?.sourceShapeId) {
    return computeAnchorPoint(arrow.binding.sourceShapeId, arrow.binding.sourceAnchor)
  }
  return arrow.startPoint
}
```

**Benefits:**
- Maximum flexibility (supports both annotation AND diagram use cases)
- Gradual complexity (start simple, add binding later)
- Backward compatible (binding is optional)
- Industry-proven (tldraw has 35k+ stars, used in production)

**Source:** [tldraw: Create an arrow](https://tldraw.dev/examples/editor-api/create-arrow), [Arrows (At Length) by Steve Ruiz](https://gitnation.com/contents/arrows-at-length)

### 5. Excalidraw Hybrid Pattern

**Key Concepts:**
- Draw arrows freely as standalone objects
- Optionally bind to shapes by drawing near them
- Arrows snap to connection points automatically
- Hand-drawn aesthetic maintains casual feel

**Benefits:**
- Natural UX (draw, then bind if needed)
- Automatic binding detection (no manual mode switching)
- Works for both sketching and structured diagrams

**Source:** Excalidraw is open-source, similar pattern to tldraw

### 6. FigJam/Miro Edge Pattern

**Key Concepts:**
- Dedicated "connector" tool separate from arrow tool
- Connectors are relationships, always bound to objects
- Independent arrows for annotations
- Two distinct tools for two use cases

**Benefits:**
- Clear separation of concerns
- Users understand when they're creating relationships vs annotations

**Drawbacks:**
- More UI complexity (two tools instead of one)
- Can't convert between types easily

**Source:** [FigJam Connectors](https://help.figma.com/hc/en-us/articles/1500004414542-Create-diagrams-and-flows-with-connectors-in-FigJam), [Miro Forum: Link Arrows](https://forum.figma.com/t/ability-to-link-arrows-and-shapes-like-in-miro/4412)

---

## Recommended Approach for TextTool

### **✅ Decision: Hybrid Pattern (tldraw-inspired)**

**Implement lines/arrows as independent node objects (Phase 1), with optional binding system (Phase 2, future).**

**Implement in Two Phases:**

**Phase 1 (NOW - 3-4 days)**: Independent line/arrow objects
- Fast to implement
- Perfect for annotation use cases (pointing, underlining, highlighting)
- No architectural complexity
- Proven by Konva, Fabric.js

**Phase 2 (FUTURE - only if needed)**: Optional binding system
- Only if users request diagram/flowchart features
- Backward compatible (binding is optional)
- Proven by tldraw, Excalidraw
- Estimated 7-10 additional days

### Why This Approach?

1. ✅ **Aligns with current product**: "FigJam-like annotation tool" needs independent arrows
2. ✅ **Fastest time-to-value**: Ship line/arrow tools in days, not weeks
3. ✅ **No over-engineering**: Don't build diagram features until validated by users
4. ✅ **Future-proof**: Can add binding later without breaking changes
5. ✅ **Industry-proven**: tldraw's pattern is battle-tested (35k+ GitHub stars)
6. ✅ **Fits existing architecture**: Works perfectly with current `CanvasObject` protocol

---

## Implementation Roadmap

### Phase 1: Independent Line/Arrow Objects (NOW)

**Goal**: Annotation tools for pointing, underlining, highlighting areas

#### Data Models

```swift
// LineObject - independent two-point line
struct LineObject: CanvasObject, StrokableObject {
    let id: UUID
    var startPoint: CGPoint    // Control point 1
    var endPoint: CGPoint      // Control point 2
    var rotation: CGFloat = 0
    var isLocked: Bool = false
    var zIndex: Int = 0

    // Stroke properties
    var strokeColor: Color = .black
    var strokeWidth: CGFloat = 2
    var strokeStyle: StrokeStyleType = .solid

    // Optional label
    var label: String = ""
    var labelAttributes: TextAttributes = .default
    var isEditingLabel: Bool = false

    // CanvasObject conformance (computed)
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

    func hitTest(_ point: CGPoint, threshold: CGFloat) -> HitTestResult? {
        // Control points (endpoints)
        if distance(point, startPoint) < threshold {
            return .controlPoint(index: 0)
        }
        if distance(point, endPoint) < threshold {
            return .controlPoint(index: 1)
        }

        // Label area
        if !label.isEmpty, labelRect().contains(point) {
            return .label
        }

        // Line segment proximity
        if distanceToLineSegment(point, startPoint, endPoint) < threshold {
            return .body
        }

        return nil
    }
}

// ArrowObject - extends line with arrowheads
struct ArrowObject: CanvasObject, StrokableObject {
    let id: UUID
    var startPoint: CGPoint
    var endPoint: CGPoint
    var rotation: CGFloat = 0
    var isLocked: Bool = false
    var zIndex: Int = 0

    // Stroke properties
    var strokeColor: Color = .black
    var strokeWidth: CGFloat = 2
    var strokeStyle: StrokeStyleType = .solid

    // Arrow-specific
    var startArrowHead: ArrowHead = .none
    var endArrowHead: ArrowHead = .filled

    enum ArrowHead: String, CaseIterable {
        case none
        case open       // V shape
        case filled     // Filled triangle
        case circle     // Circle endpoint
        case diamond    // Diamond shape
    }

    // Optional label
    var label: String = ""
    var labelAttributes: TextAttributes = .default
    var isEditingLabel: Bool = false

    // Same computed properties as LineObject
    var position: CGPoint { /* ... */ }
    var size: CGSize { /* ... */ }
    var midPoint: CGPoint { /* ... */ }
}
```

#### Implementation Steps

**Day 1-2: Data Models & Integration**
- Create `LineObject.swift` conforming to `CanvasObject`, `StrokableObject`
- Create `ArrowObject.swift` with `ArrowHead` enum
- Add `.line` and `.arrow` to `AnyCanvasObject.ObjectType`
- Update `AnyCanvasObject` type erasure wrapper
- Unit tests for hit testing, bounding box

**Day 2-3: View Rendering**
- Create `LineObjectView.swift` - renders line path with stroke
- Create `ArrowObjectView.swift` - renders line + arrowhead shapes
- Implement arrowhead geometry (triangle, V, circle, diamond)
- Control point handles when selected
- Label rendering at midpoint

**Day 3-4: Drawing Tools & UX**
- Add `.line` and `.arrow` to `DrawingTool` enum
- Implement two-point drag-to-create gesture
- Control point dragging (reshape line by moving endpoints)
- Toolbar controls: arrowhead style picker, stroke style
- Double-click midpoint to add/edit label
- Comprehensive testing

**Deliverable**: Fully functional line and arrow tools for annotations.

---

### Phase 2: Optional Binding System (FUTURE - Only If Needed)

**Trigger Conditions**:
- Users explicitly request flowchart/diagram features
- Pain points observed with manual arrow repositioning
- Use cases evolve beyond pure annotation

**Implementation** (7-10 days when needed):

```swift
// Optional binding for connection-aware arrows
struct ArrowBinding: Codable {
    var sourceObjectId: UUID?
    var targetObjectId: UUID?
    var sourceAnchor: AnchorPoint = .auto
    var targetAnchor: AnchorPoint = .auto

    enum AnchorPoint {
        case auto                    // Closest edge point
        case center                  // Object center
        case edge(Edge)             // Specific edge
        case point(CGPoint)         // Normalized (0-1) point
    }
}

// Enhanced ArrowObject with optional binding
extension ArrowObject {
    var binding: ArrowBinding? = nil  // NEW property

    var effectiveStartPoint: CGPoint {
        if let binding = binding, let sourceId = binding.sourceObjectId {
            return computeAnchorPoint(for: sourceId, anchor: binding.sourceAnchor)
        }
        return startPoint  // Fall back to manual position
    }

    var effectiveEndPoint: CGPoint {
        if let binding = binding, let targetId = binding.targetObjectId {
            return computeAnchorPoint(for: targetId, anchor: binding.targetAnchor)
        }
        return endPoint
    }

    var isBound: Bool {
        binding?.sourceObjectId != nil || binding?.targetObjectId != nil
    }
}

// ViewModel extensions
extension CanvasViewModel {
    func bindArrow(_ arrowId: UUID, source: UUID?, target: UUID?) {
        // Set binding, auto-update when shapes move
    }

    func unbindArrow(_ arrowId: UUID) {
        // Freeze current positions, remove binding
    }

    func objectDidMove(_ id: UUID) {
        // Update all arrows bound to this object
    }
}
```

**Features**:
- Snap-to-bind UX (drag arrow near shape, auto-bind)
- Visual connection points on shapes
- Bind/unbind toggle in context menu
- Auto-update arrow positions when shapes move
- Smart anchor point calculation
- Connection dots visual feedback

---

## Optional Scene Graph Enhancements

**Note**: The following enhancements are **optional** and only needed for advanced use cases or performance at scale (100+ objects).

### When to Consider Scene Graph

**Implement hierarchical scene graph if:**
- You need complex nested grouping (groups within groups)
- Performance degrades with 50+ objects (spatial indexing)
- You want transform inheritance (move group, children follow)
- Users request layer management (like Photoshop)

**Don't implement if:**
- Current flat array performs well
- No user requests for advanced grouping
- Complexity outweighs benefits

### Scene Graph Components (If Needed)

#### 1. SceneNode Protocol (Enhanced CanvasObject)

```swift
/// Enhanced protocol with hierarchy support
protocol SceneNode: Identifiable {
    var id: UUID { get }
    var position: CGPoint { get set }
    var size: CGSize { get set }
    var rotation: CGFloat { get set }
    var scale: CGPoint { get set }  // NEW: non-uniform scaling
    var opacity: CGFloat { get set }  // NEW: transparency
    var isLocked: Bool { get set }
    var isVisible: Bool { get set }  // NEW: visibility toggle
    var zIndex: Int { get set }

    // Hierarchy (NEW)
    var parent: UUID? { get set }
    var children: [UUID] { get set }

    // Metadata
    var name: String? { get set }  // NEW: user-friendly label
    var tags: Set<String> { get set }  // NEW: for filtering/searching

    // Methods
    func contains(_ point: CGPoint) -> Bool
    func boundingBox() -> CGRect
    func hitTest(_ point: CGPoint, threshold: CGFloat) -> HitTestResult?

    // Transform (NEW)
    func worldTransform() -> CGAffineTransform  // combined parent transforms
    func localToWorld(_ point: CGPoint) -> CGPoint
    func worldToLocal(_ point: CGPoint) -> CGPoint
}
```

#### 2. Node Types Hierarchy

```swift
enum NodeType: String, Codable {
    // Visual Nodes
    case shape
    case text
    case image
    case path  // for freehand drawing

    // Container Nodes
    case group  // for multi-selection, organization
    case layer  // rendering layer (like Konva)

    // Connection Nodes
    case line
    case arrow
    case connector  // smart connector with routing

    // Annotation Nodes
    case note
    case sticker
    case autoNumber
    case mosaic

    // Composite Nodes
    case component  // reusable node template
}
```

#### 3. Scene Graph Structure

```swift
/// Scene graph manager - replaces flat array
@MainActor
class SceneGraph: ObservableObject {
    // Node storage (indexed by ID for O(1) lookup)
    private var nodes: [UUID: AnySceneNode] = [:]

    // Hierarchy tracking
    private var rootNodes: [UUID] = []  // top-level nodes

    // Spatial index for fast hit testing
    private var spatialIndex: QuadTree<UUID>?

    // Rendering order cache (computed from zIndex + hierarchy)
    private var renderOrder: [UUID] = []
    private var renderOrderDirty = true

    // MARK: - Node Management

    func addNode(_ node: any SceneNode, parent: UUID? = nil) {
        let wrapped = AnySceneNode(node)
        nodes[node.id] = wrapped

        if let parentId = parent {
            nodes[parentId]?.children.append(node.id)
        } else {
            rootNodes.append(node.id)
        }

        markDirty()
    }

    func removeNode(_ id: UUID) {
        // Remove from parent's children
        if let node = nodes[id], let parentId = node.parent {
            nodes[parentId]?.children.removeAll { $0 == id }
        } else {
            rootNodes.removeAll { $0 == id }
        }

        // Remove all descendants
        removeDescendants(of: id)
        nodes.removeValue(forKey: id)
        markDirty()
    }

    func getNode(_ id: UUID) -> AnySceneNode? {
        nodes[id]
    }

    // MARK: - Hierarchy Operations

    func children(of id: UUID) -> [AnySceneNode] {
        guard let node = nodes[id] else { return [] }
        return node.children.compactMap { nodes[$0] }
    }

    func ancestors(of id: UUID) -> [AnySceneNode] {
        var result: [AnySceneNode] = []
        var current = nodes[id]

        while let node = current, let parentId = node.parent {
            if let parent = nodes[parentId] {
                result.append(parent)
                current = parent
            } else {
                break
            }
        }

        return result
    }

    func descendants(of id: UUID) -> [AnySceneNode] {
        guard let node = nodes[id] else { return [] }
        var result: [AnySceneNode] = []

        for childId in node.children {
            if let child = nodes[childId] {
                result.append(child)
                result.append(contentsOf: descendants(of: childId))
            }
        }

        return result
    }

    // MARK: - Rendering Order

    /// Get nodes in render order (depth-first, respecting zIndex)
    func getRenderOrder() -> [AnySceneNode] {
        if renderOrderDirty {
            rebuildRenderOrder()
        }
        return renderOrder.compactMap { nodes[$0] }
    }

    private func rebuildRenderOrder() {
        var order: [UUID] = []

        // Sort root nodes by zIndex
        let sortedRoots = rootNodes.sorted { id1, id2 in
            (nodes[id1]?.zIndex ?? 0) < (nodes[id2]?.zIndex ?? 0)
        }

        // Depth-first traversal
        for rootId in sortedRoots {
            appendNodeAndChildren(rootId, to: &order)
        }

        renderOrder = order
        renderOrderDirty = false
    }

    private func appendNodeAndChildren(_ id: UUID, to order: inout [UUID]) {
        guard let node = nodes[id] else { return }
        order.append(id)

        // Sort children by zIndex before traversing
        let sortedChildren = node.children.sorted { id1, id2 in
            (nodes[id1]?.zIndex ?? 0) < (nodes[id2]?.zIndex ?? 0)
        }

        for childId in sortedChildren {
            appendNodeAndChildren(childId, to: &order)
        }
    }

    // MARK: - Hit Testing

    /// Find topmost node at point (reverse render order)
    func hitTest(at point: CGPoint, threshold: CGFloat = 8) -> (node: AnySceneNode, result: HitTestResult)? {
        let order = getRenderOrder()

        // Test in reverse order (topmost first)
        for node in order.reversed() {
            guard node.isVisible && !node.isLocked else { continue }

            // Transform point to node's local space
            let localPoint = node.worldToLocal(point)

            if let hitResult = node.hitTest(localPoint, threshold: threshold) {
                return (node, hitResult)
            }
        }

        return nil
    }

    /// Find all nodes in a region (for marquee selection)
    func hitTest(in rect: CGRect) -> [AnySceneNode] {
        getRenderOrder().filter { node in
            node.isVisible && !node.isLocked && rect.intersects(node.boundingBox())
        }
    }

    // MARK: - Spatial Indexing

    func rebuildSpatialIndex(canvasSize: CGSize) {
        spatialIndex = QuadTree(bounds: CGRect(origin: .zero, size: canvasSize))

        for (id, node) in nodes {
            spatialIndex?.insert(id, at: node.boundingBox())
        }
    }

    private func markDirty() {
        renderOrderDirty = true
        // Trigger SwiftUI update
        objectWillChange.send()
    }

    private func removeDescendants(of id: UUID) {
        guard let node = nodes[id] else { return }

        for childId in node.children {
            removeDescendants(of: childId)
            nodes.removeValue(forKey: childId)
        }
    }
}
```

#### 4. Group Node (Container)

```swift
/// Group node for organizing and transforming multiple nodes together
struct GroupNode: SceneNode {
    let id: UUID
    var position: CGPoint
    var size: CGSize
    var rotation: CGFloat = 0
    var scale: CGPoint = CGPoint(x: 1, y: 1)
    var opacity: CGFloat = 1
    var isLocked: Bool = false
    var isVisible: Bool = true
    var zIndex: Int = 0
    var parent: UUID?
    var children: [UUID] = []
    var name: String?
    var tags: Set<String> = []

    // Group-specific
    var clipToBounds: Bool = false
    var backgroundColor: Color?

    func contains(_ point: CGPoint) -> Bool {
        // A group contains a point if any of its children do
        // This requires access to scene graph, so implement in SceneGraph
        false
    }

    func boundingBox() -> CGRect {
        // Union of all children's bounding boxes
        // Also requires access to scene graph
        CGRect(origin: position, size: size)
    }

    func hitTest(_ point: CGPoint, threshold: CGFloat) -> HitTestResult? {
        nil  // Groups delegate hit testing to children
    }
}
```

#### 5. Connection System (React Flow inspired)

```swift
/// Connection between two nodes
struct Connection: Identifiable, Codable {
    let id: UUID
    var source: UUID  // source node ID
    var target: UUID  // target node ID
    var sourceHandle: String?  // handle name (e.g., "right", "output-0")
    var targetHandle: String?

    // Visual properties
    var strokeColor: Color = .black
    var strokeWidth: CGFloat = 2
    var strokeStyle: StrokeStyleType = .solid
    var arrowHead: ArrowHead = .filled

    // Connection routing
    var routingType: RoutingType = .bezier
    var waypoints: [CGPoint] = []  // for custom routing

    enum RoutingType {
        case straight
        case bezier
        case step
        case orthogonal  // right-angle routing
    }

    enum ArrowHead {
        case none, open, filled, diamond, circle
    }
}

/// Handle on a node for connections
struct NodeHandle: Identifiable {
    let id: String  // unique within the node
    var position: HandlePosition
    var offset: CGPoint = .zero  // offset from auto position
    var type: HandleType = .both

    enum HandlePosition {
        case top, right, bottom, left
        case auto  // positioned automatically
        case custom(CGPoint)  // absolute position within node
    }

    enum HandleType {
        case source  // can only start connections
        case target  // can only receive connections
        case both
    }
}

/// Protocol for nodes that support connections
protocol Connectable: SceneNode {
    var handles: [NodeHandle] { get set }
    func handlePosition(_ handleId: String) -> CGPoint?
}
```

### Integration with Existing Code

#### Migration Strategy

**Phase 1: Add Scene Graph (Non-Breaking)**
```swift
// In CanvasViewModel
@Published var sceneGraph = SceneGraph()

// Dual mode: maintain both old and new systems
@Published private(set) var objects: [AnyCanvasObject] = [] {
    didSet {
        // Sync to scene graph
        syncToSceneGraph()
    }
}

private func syncToSceneGraph() {
    // Keep scene graph in sync during migration
    sceneGraph.clear()
    for obj in objects {
        sceneGraph.addNode(convertToSceneNode(obj))
    }
}
```

**Phase 2: Replace Operations Incrementally**
- ✅ Replace hit testing with `sceneGraph.hitTest()`
- ✅ Replace rendering with `sceneGraph.getRenderOrder()`
- ✅ Add grouping support for multi-selection
- ✅ Migrate selection to use scene graph

**Phase 3: Full Migration**
- Remove legacy `objects` array
- Use `sceneGraph` exclusively
- Add connection support
- Implement spatial indexing

### Key Architectural Benefits

#### 1. Hierarchical Transforms (Konva Pattern)

```swift
// Before: Manual transform calculation
let worldPoint = CGPoint(
    x: child.position.x + parent.position.x,
    y: child.position.y + parent.position.y
)

// After: Automatic through scene graph
let worldPoint = child.localToWorld(localPoint)
```

#### 2. Efficient Group Operations

```swift
// Before: Update each selected object individually
for id in selectedIds {
    if let index = objects.firstIndex(where: { $0.id == id }) {
        objects[index].position.x += delta.x
        objects[index].position.y += delta.y
    }
}

// After: Move group node, children transform automatically
if let group = sceneGraph.getNode(groupId) as? GroupNode {
    group.position.x += delta.x
    group.position.y += delta.y
}
```

#### 3. Spatial Indexing for Performance

```swift
// Before: O(n) hit testing
func hitTest(at point: CGPoint) -> AnyCanvasObject? {
    for obj in objects.reversed() {  // O(n)
        if obj.contains(point) {
            return obj
        }
    }
    return nil
}

// After: O(log n) with QuadTree
func hitTest(at point: CGPoint) -> AnySceneNode? {
    let candidates = spatialIndex.query(point)  // O(log n)
    for id in candidates.reversed() {
        if let node = sceneGraph.getNode(id), node.contains(point) {
            return node
        }
    }
    return nil
}
```

#### 4. Connection Support (React Flow Pattern)

```swift
// New capability: Link nodes with arrows
let connection = Connection(
    id: UUID(),
    source: rectNodeId,
    target: circleNodeId,
    sourceHandle: "right",
    targetHandle: "left",
    routingType: .bezier
)

connectionManager.addConnection(connection)

// Auto-update when nodes move
class ConnectionManager {
    func updateConnection(_ id: UUID) {
        guard let conn = connections[id] else { return }
        let startPoint = sceneGraph.getNode(conn.source)?.handlePosition(conn.sourceHandle ?? "right")
        let endPoint = sceneGraph.getNode(conn.target)?.handlePosition(conn.targetHandle ?? "left")
        // Render bezier curve between points
    }
}
```

### Performance Optimizations

#### 1. Dirty Region Tracking (Konva Pattern)

```swift
class DirtyRegionTracker {
    private var dirtyRegions: [CGRect] = []

    func markDirty(_ rect: CGRect) {
        dirtyRegions.append(rect)
    }

    func getDirtyRegion() -> CGRect? {
        guard !dirtyRegions.isEmpty else { return nil }
        return dirtyRegions.reduce(into: dirtyRegions[0]) { result, rect in
            result = result.union(rect)
        }
    }

    func clear() {
        dirtyRegions.removeAll()
    }
}

// Only redraw dirty regions
func render() {
    if let dirtyRect = dirtyTracker.getDirtyRegion() {
        let affectedNodes = sceneGraph.hitTest(in: dirtyRect)
        render(affectedNodes, in: dirtyRect)
    }
    dirtyTracker.clear()
}
```

#### 2. Object Pooling

```swift
class NodePool<T: SceneNode> {
    private var available: [T] = []
    private let factory: () -> T

    func acquire() -> T {
        available.popLast() ?? factory()
    }

    func release(_ node: T) {
        available.append(node)
    }
}
```

### Serialization (Fabric.js Pattern)

```swift
extension SceneGraph {
    /// Export to JSON (for save/load)
    func toJSON() -> [String: Any] {
        [
            "version": "1.0",
            "nodes": nodes.values.map { $0.toJSON() },
            "connections": connectionManager.connections.map { $0.toJSON() }
        ]
    }

    /// Import from JSON
    static func fromJSON(_ json: [String: Any]) -> SceneGraph {
        let graph = SceneGraph()

        if let nodesData = json["nodes"] as? [[String: Any]] {
            for nodeData in nodesData {
                if let node = createNode(from: nodeData) {
                    graph.addNode(node)
                }
            }
        }

        return graph
    }
}
```

## Implementation Roadmap

### Phase 1: Foundation (2-3 days)
- [ ] Implement `SceneNode` protocol
- [ ] Create `SceneGraph` class
- [ ] Add `GroupNode` type
- [ ] Implement transform propagation
- [ ] Add basic unit tests

### Phase 2: Integration (3-4 days)
- [ ] Dual-mode operation (both systems)
- [ ] Migrate hit testing to scene graph
- [ ] Migrate rendering to scene graph
- [ ] Add grouping for multi-selection
- [ ] Comprehensive testing

### Phase 3: Connections (2-3 days)
- [ ] Implement `Connection` and `NodeHandle`
- [ ] Add `ConnectionManager`
- [ ] Create line/arrow rendering with routing
- [ ] Add UI for creating connections

### Phase 4: Optimization (2-3 days)
- [ ] Implement `QuadTree` spatial index
- [ ] Add dirty region tracking
- [ ] Optimize rendering pipeline
- [ ] Performance profiling and tuning

### Phase 5: Complete Migration (1-2 days)
- [ ] Remove legacy `objects` array
- [ ] Clean up compatibility code
- [ ] Update all tests
- [ ] Documentation

**Total Estimate: 10-15 days**

## Comparison: Before vs After

| Feature | Current (Flat Array) | Proposed (Scene Graph) |
|---------|---------------------|------------------------|
| Object Storage | `[AnyCanvasObject]` | `SceneGraph` with `[UUID: AnySceneNode]` |
| Grouping | Manual multi-selection | Native hierarchical groups |
| Transform | Per-object calculation | Automatic inheritance |
| Hit Testing | O(n) linear search | O(log n) with QuadTree |
| Rendering Order | Array order + zIndex | Depth-first with zIndex |
| Connections | Not supported | Native Connection type |
| Serialization | Custom per-object | Unified JSON export |
| Memory | Duplicated data in views | Single source of truth |

## Summary: Lines/Arrows as Nodes or Edges?

### ✅ **Answer: Both (Hybrid Approach)**

**Phase 1 (Implement Now)**: Independent node objects
- Lines and arrows are `CanvasObject` structs with `startPoint`/`endPoint`
- Users drag to create, drag endpoints to reshape
- Perfect for annotation use cases (pointing at UI, underlining text, etc.)
- **Industry precedent**: Konva, Fabric.js use this pattern
- **Implementation time**: 3-4 days
- **Complexity**: Low (fits existing architecture perfectly)

**Phase 2 (Future - Only If Needed)**: Optional binding system
- Add optional `binding: ArrowBinding?` property to `ArrowObject`
- Arrows can optionally connect to shapes (auto-update when shapes move)
- Backward compatible (binding is optional, arrows work without it)
- **Industry precedent**: tldraw, Excalidraw use this pattern
- **Implementation time**: 7-10 additional days
- **Trigger**: User requests for flowchart/diagram features

### Why This Decision?

1. ✅ **Product alignment**: TextTool is an annotation tool, needs independent arrows
2. ✅ **Fastest value**: Ship functional line/arrow tools in days, not weeks
3. ✅ **No over-engineering**: Don't build features users haven't requested
4. ✅ **Future-proof**: Can add binding later without breaking changes
5. ✅ **Battle-tested**: tldraw (35k+ stars) proves this pattern works

### Comparison to Alternatives

| Approach | Use Case | Pros | Cons | Recommendation |
|----------|----------|------|------|----------------|
| **Nodes Only** | Annotation | Simple, fast | Manual repositioning | ✅ **Phase 1** |
| **Edges Only** | Diagrams | Auto-update | Can't annotate | ❌ Too limited |
| **Hybrid (tldraw)** | Both | Maximum flexibility | Two implementations | ✅ **Long-term** |

### Next Steps

1. **Implement Phase 1**: Create `LineObject` and `ArrowObject` as independent nodes (3-4 days)
2. **Ship and monitor**: Release line/arrow tools, gather user feedback
3. **Decide on Phase 2**: Only implement binding if users request diagram features
4. **Optional enhancements**: Scene graph / spatial indexing only if performance demands it

---

## Conclusion

Your current architecture **already implements the node-based pattern**. The question was specifically about lines/arrows, and the answer is:

**Start with independent node objects (Phase 1), optionally add binding later (Phase 2).**

This approach:
- ✅ Fits your existing `CanvasObject` architecture perfectly
- ✅ Delivers value quickly (annotation tools)
- ✅ Keeps options open (can add diagram features later)
- ✅ Follows industry best practices (tldraw, Excalidraw)
- ✅ Avoids over-engineering (only build what's needed)

The optional scene graph enhancements (hierarchical grouping, spatial indexing) are **nice-to-have** but not required for basic line/arrow functionality. Consider them only if performance or complexity demands it.

## Sources

### Canvas Library Architecture
- [Konva Framework Overview](https://konvajs.org/docs/overview.html)
- [Getting started with React and Konva](https://konvajs.org/docs/react/index.html)
- [Connect objects HTML5 canvas with Konva](https://konvajs.org/docs/sandbox/Connected_Objects.html)
- [HTML5 canvas Arrow Tutorial - Konva](https://konvajs.org/docs/shapes/Arrow.html)
- [Konva.js vs Fabric.js: In-Depth Technical Comparison](https://medium.com/@www.blog4j.com/konva-js-vs-fabric-js-in-depth-technical-comparison-and-use-case-analysis-9c247968dd0f)
- [Fabric.js vs Konva Comparison](https://stackshare.io/stackups/fabricjs-vs-konva)
- [How I choose Fabric.js again](https://0ro.github.io/posts/how-i-choose-fabricjs-again/)

### Node Graph and Diagramming
- [React Flow Examples](https://reactflow.dev/examples)
- [React Flow in Enterprise Applications](https://medium.com/react-digital-garden/react-flow-examples-2cbb0bab4404)
- [tldraw: Create an arrow](https://tldraw.dev/examples/editor-api/create-arrow)
- [Arrows (At Length) by Steve Ruiz](https://gitnation.com/contents/arrows-at-length)

### Product-Specific Patterns
- [Create diagrams and flows with connectors in FigJam](https://help.figma.com/hc/en-us/articles/1500004414542-Create-diagrams-and-flows-with-connectors-in-FigJam)
- [Ability to link arrows and shapes like in Miro - Figma Forum](https://forum.figma.com/t/ability-to-link-arrows-and-shapes-like-in-miro/4412)
