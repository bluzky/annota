# ADR-001: Node-Based Architecture (Independent Nodes vs Connected Edges)

**Status:** ✅ Accepted and Implemented

**Date:** 2025-02

**Decision Makers:** Architecture Team

---

## Context

A critical architectural decision for the Annota canvas application was choosing between two fundamental patterns: Should all objects (including lines and arrows) be implemented as **independent graphical objects (nodes)** that users can freely position, or should lines and arrows be **connected edges** that automatically bind to and follow other shapes (graph-based approach)?

This decision impacts:
- Implementation complexity
- Use case support (annotation vs diagramming)
- User experience
- Future extensibility
- Time to market

## Decision

**We will implement lines and arrows as independent node objects (Phase 1), with an optional binding system for shape connections (Phase 2) to be added only if diagram features are requested by users.**

### Phase 1: Independent Node Objects (Implemented)
- Lines and arrows are `CanvasObject` structs with `startPoint` and `endPoint` properties
- Users drag-to-create and manually reposition via control point dragging
- No automatic binding to other shapes
- Perfect for annotation use cases (pointing, underlining, highlighting)

### Phase 2: Optional Binding System (Future)
- Add optional `binding: ArrowBinding?` property to arrow objects
- Arrows can optionally connect to shapes and auto-update when shapes move
- Backward compatible - binding is optional, arrows work independently without it
- Only implement if users explicitly request flowchart/diagram features

## Rationale

### Why Independent Nodes (Phase 1)?

1. **Product Alignment**: Annota is positioned as a FigJam-like annotation tool, not a diagramming application. The primary use cases are:
   - Pointing at UI elements in screenshots
   - Underlining or highlighting text
   - Adding visual emphasis to areas
   - Drawing freeform connectors

2. **Fastest Time-to-Value**: Independent nodes can be shipped in 3-4 days vs 10-14 days for a full diagram system. This allows rapid validation with users.

3. **Existing Architecture Fit**: The current `CanvasObject` protocol already supports this pattern perfectly. No major architectural changes required.

4. **No Over-Engineering**: Don't build complex diagram features until users explicitly request them. Follow lean/agile principles.

5. **Industry Validation**: Konva.js and Fabric.js (industry-standard canvas libraries) both use independent nodes for basic line/arrow tools.

### Why Optional Binding (Phase 2)?

1. **Future-Proofing**: Leaves the door open for diagram features without requiring a complete rewrite

2. **Backward Compatibility**: Binding is an optional property - existing arrows continue to work independently

3. **Battle-Tested Pattern**: tldraw (35k+ GitHub stars) and Excalidraw both use this hybrid approach successfully

4. **User-Driven**: Only implement when validated by real user needs, not speculation

### Why Not Edges-Only?

An edges-only approach (like React Flow) would:
- ❌ Not support annotation use cases (can't point at arbitrary locations)
- ❌ Require complex node-edge graph infrastructure upfront
- ❌ Be over-engineered for current product needs
- ❌ Take 2-3x longer to implement
- ❌ Force diagram mental model on annotation users

## Consequences

### Positive

- ✅ **Fast shipping**: Line/arrow tools delivered in days, not weeks
- ✅ **Simple implementation**: Fits existing architecture with minimal changes
- ✅ **User flexibility**: Manual positioning gives precise control
- ✅ **Future extensibility**: Can add binding later without breaking changes
- ✅ **Lower maintenance**: Simpler codebase with fewer edge cases

### Negative

- ⚠️ **Manual repositioning**: Users must manually update arrow positions when shapes move
- ⚠️ **Diagram limitations**: Not optimal for flowcharts/org charts until Phase 2
- ⚠️ **Potential confusion**: Users coming from diagramming tools may expect auto-binding

### Mitigations

- **Clear UX**: Make it obvious that arrows are independent objects (via control points)
- **Future upgrade path**: Document how to add binding in Phase 2 if needed
- **User education**: Documentation explains the annotation-first approach
- **Monitor feedback**: Track user requests for diagram features to validate Phase 2 need

## Implementation

### Phase 1: Independent Nodes (Completed)

**Data Models:**
```swift
struct LineObject: CanvasObject, StrokableObject {
    let id: UUID
    var startPoint: CGPoint    // Control point 1
    var endPoint: CGPoint      // Control point 2
    var label: String          // Optional text label
    // ... CanvasObject properties
}

struct ArrowObject: CanvasObject, StrokableObject {
    let id: UUID
    var startPoint: CGPoint
    var endPoint: CGPoint
    var startArrowHead: ArrowHead
    var endArrowHead: ArrowHead  // .none, .open, .filled, etc.
    var label: String
    // ... CanvasObject properties
}
```

**Key Implementation Points:**
- Control points rendered as draggable handles when selected
- `usesControlPoints` flag set to `true` (no selection box)
- Hit testing: endpoints → line segment → label
- Shift+drag for angle-constrained drawing (15° increments)

### Phase 2: Optional Binding (If Needed)

**Trigger Conditions:**
- Multiple user requests for flowchart/diagram features
- Observed pain points with manual arrow repositioning
- Product strategy shift toward diagramming use cases

**Extension Pattern:**
```swift
struct ArrowBinding: Codable {
    var sourceObjectId: UUID?
    var targetObjectId: UUID?
    var sourceAnchor: AnchorPoint  // .auto, .center, .edge(), etc.
    var targetAnchor: AnchorPoint
}

extension ArrowObject {
    var binding: ArrowBinding? = nil  // NEW: optional property

    var effectiveStartPoint: CGPoint {
        binding?.sourceObjectId != nil
            ? computeAnchorPoint(...)
            : startPoint  // fallback to manual
    }
}
```

**Estimated Effort:** 7-10 days when implemented

## Alternatives Considered

### Alternative 1: Edges-Only (React Flow Pattern)
**Rejected because:**
- Doesn't support annotation use cases
- Over-engineered for current needs
- Slower time-to-market
- Poor fit for product positioning

### Alternative 2: Both Tools (FigJam/Miro Pattern)
Separate "Arrow" tool (independent) and "Connector" tool (bound edges).

**Rejected because:**
- UI complexity - two tools instead of one
- Confusing for users - which to choose?
- Can't convert between types easily
- Hybrid pattern achieves same flexibility with one tool

### Alternative 3: Full Scene Graph (Konva Pattern)
Hierarchical node tree with automatic transform inheritance.

**Deferred because:**
- Overkill for current object count (<100 objects typical)
- Adds architectural complexity
- No performance issues to solve yet
- Can be added later if needed (separate decision)

## Related Decisions

- **ADR-002**: Plugin-based tool architecture (enables easy addition of binding in Phase 2)
- **ADR-003**: Protocol-based object model (supports optional capabilities like binding)
- **ADR-004**: Framework extraction (AnotarCanvas) (keeps binding system reusable)

## References

### Industry Analysis
- **tldraw**: [Create an arrow](https://tldraw.dev/examples/editor-api/create-arrow) - Hybrid approach with optional binding
- **Excalidraw**: Open-source whiteboard using similar independent-with-binding pattern
- **Konva.js**: [Arrow Tutorial](https://konvajs.org/docs/shapes/Arrow.html) - Independent shapes
- **React Flow**: [Examples](https://reactflow.dev/examples) - Edge-based approach for diagrams

### Internal Documentation
- [ARCHITECTURE.md](../ARCHITECTURE.md) - Overall system architecture
- [docs/adding-a-tool.md](adding-a-tool.md) - Tool implementation guide
- [AnotarCanvas-API.md](AnotarCanvas-API.md) - Framework API reference

## Review and Updates

**Last Reviewed:** 2025-02

**Next Review:** When considering Phase 2 implementation (user-driven)

**Status History:**
- 2025-02: Proposed and accepted
- 2025-02: Phase 1 implemented and shipped
- Phase 2: Awaiting user validation
