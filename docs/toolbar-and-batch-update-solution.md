# Toolbar & Batch Update Attributes - Complete Solution

## Overview

This document consolidates the complete solution for:
1. **Batch attribute updates** - Update multiple object properties at once
2. **Sub-toolbar** - Context-sensitive controls below main toolbar
3. **Tool attribute memory** - Tools remember and apply last-used settings

---

## Part 1: Batch Attribute Update System

### 1.1 Attribute Model

```swift
// AnotarCanvas/Models/ObjectAttributes.swift

import SwiftUI

/// Dictionary of attribute updates
public typealias ObjectAttributes = [String: Any]

// Well-known attribute keys
public extension ObjectAttributes {
    // Geometry (all CanvasObject)
    static let position = "position"
    static let size = "size"
    static let rotation = "rotation"
    static let zIndex = "zIndex"
    static let isLocked = "isLocked"

    // Stroke (StrokableObject)
    static let strokeColor = "strokeColor"
    static let strokeWidth = "strokeWidth"
    static let strokeStyle = "strokeStyle"

    // Fill (FillableObject)
    static let fillColor = "fillColor"
    static let fillOpacity = "fillOpacity"

    // Text (TextContentObject)
    static let text = "text"
    static let textColor = "textColor"
    static let fontSize = "fontSize"
}
```

### 1.2 Type-Erased Mutation in AnyCanvasObject

```swift
// Modify AnotarCanvas/Models/AnyCanvasObject.swift

public struct AnyCanvasObject: Identifiable {
    // ... existing properties ...

    // NEW: Closures for type-erased mutation
    private let _mutate: (ObjectAttributes) -> Any
    private let _rebuild: (Any) -> AnyCanvasObject

    @MainActor
    init<T: CanvasObject>(_ object: T) {
        // ... existing initialization ...

        // Capture mutation logic for type T
        self._mutate = { attributes in
            var mutableCopy = object
            Self.applyAttributesGeneric(attributes, to: &mutableCopy)
            return mutableCopy
        }

        // Capture rebuild logic for type T
        self._rebuild = { mutatedAny in
            guard let mutated = mutatedAny as? T else {
                fatalError("Type mismatch in rebuild")
            }
            return AnyCanvasObject(mutated)
        }
    }

    /// Apply attributes and return new wrapper (completely type-erased!)
    @MainActor
    public func applying(_ attributes: ObjectAttributes) -> AnyCanvasObject {
        let mutated = _mutate(attributes)
        return _rebuild(mutated)
    }

    // MARK: - Generic Attribute Application

    private static func applyAttributesGeneric<T: CanvasObject>(
        _ attributes: ObjectAttributes,
        to object: inout T
    ) {
        // Geometry (all CanvasObject)
        if let pos = attributes["position"] as? CGPoint {
            object.position = pos
        }
        if let size = attributes["size"] as? CGSize {
            object.size = size
        }
        if let rot = attributes["rotation"] as? CGFloat {
            object.rotation = rot
        }
        if let z = attributes["zIndex"] as? Int {
            object.zIndex = z
        }
        if let locked = attributes["isLocked"] as? Bool {
            object.isLocked = locked
        }

        // Stroke properties (protocol-based)
        if var strokeable = object as? any StrokableObject {
            var modified = false
            if let color = attributes["strokeColor"] as? Color {
                strokeable.strokeColor = color
                modified = true
            }
            if let width = attributes["strokeWidth"] as? CGFloat {
                strokeable.strokeWidth = width
                modified = true
            }
            if let style = attributes["strokeStyle"] as? StrokeStyleType {
                strokeable.strokeStyle = style
                modified = true
            }
            if modified, let updated = strokeable as? T {
                object = updated
            }
        }

        // Fill properties (protocol-based)
        if var fillable = object as? any FillableObject {
            var modified = false
            if let color = attributes["fillColor"] as? Color {
                fillable.fillColor = color
                modified = true
            }
            if let opacity = attributes["fillOpacity"] as? CGFloat {
                fillable.fillOpacity = opacity
                modified = true
            }
            if modified, let updated = fillable as? T {
                object = updated
            }
        }

        // Text properties (protocol-based)
        if var textContent = object as? any TextContentObject {
            var modified = false
            if let text = attributes["text"] as? String {
                textContent.text = text
                modified = true
            }
            if let color = attributes["textColor"] as? Color {
                textContent.textColor = color
                modified = true
            }
            if let size = attributes["fontSize"] as? CGFloat {
                textContent.fontSize = size
                modified = true
            }
            if modified, let updated = textContent as? T {
                object = updated
            }
        }
    }
}
```

### 1.3 ViewModel Batch Update Methods

```swift
// Add to AnotarCanvas/ViewModels/CanvasViewModel.swift

// MARK: - Batch Attribute Updates

/// Update attributes on a specific object
public func updateObject(_ objectId: UUID, attributes: ObjectAttributes) {
    guard let index = objectIndex(withId: objectId) else { return }
    objects[index] = objects[index].applying(attributes)
}

/// Update attributes on all selected objects
public func updateSelected(_ attributes: ObjectAttributes) {
    for id in selectedIds {
        updateObject(id, attributes: attributes)
    }
}
```

---

## Part 2: Tool Attribute Memory

### 2.1 Tool Attributes Storage in ViewModel

```swift
// Add to AnotarCanvas/ViewModels/CanvasViewModel.swift

// MARK: - Tool Attribute State

/// Stores last-used attributes for each tool (persists across tool switches)
@Published public var toolAttributes: [String: ObjectAttributes] = [:]

/// Get/set attributes for the currently selected tool
public var currentToolAttributes: ObjectAttributes {
    get {
        toolAttributes[selectedTool.id] ?? defaultToolAttributes
    }
    set {
        toolAttributes[selectedTool.id] = newValue
    }
}

/// Default attributes for new tools
private var defaultToolAttributes: ObjectAttributes {
    [
        "strokeColor": Color.black,
        "strokeWidth": 2.0,
        "strokeStyle": StrokeStyleType.solid,
        "fillColor": Color.white,
        "fillOpacity": 1.0,
        "textColor": Color.black,
        "fontSize": 16.0
    ]
}

/// Update a specific attribute for the current tool
public func updateToolAttribute(key: String, value: Any) {
    var attrs = currentToolAttributes
    attrs[key] = value
    currentToolAttributes = attrs
}
```

### 2.2 Tool Integration Example

```swift
// Example: AnotarCanvas/Tools/ShapeTool/RectangleTool.swift

public struct RectangleTool: CanvasTool {
    // ... existing code ...

    public func handleDragEnded(
        start: CGPoint,
        end: CGPoint,
        viewModel: CanvasViewModel,
        shiftHeld: Bool
    ) {
        let (position, size) = calculateFrame(start: start, end: end, shiftHeld: shiftHeld)
        guard size.width >= 1 && size.height >= 1 else { return }

        // Get stored tool attributes
        let attrs = viewModel.currentToolAttributes

        var shape = ShapeObject(
            position: position,
            size: size,
            svgPath: svgPath,
            toolId: toolType.id
        )

        // Apply tool attributes to new object
        if let strokeColor = attrs["strokeColor"] as? Color {
            shape.strokeColor = strokeColor
        }
        if let strokeWidth = attrs["strokeWidth"] as? CGFloat {
            shape.strokeWidth = strokeWidth
        }
        if let strokeStyle = attrs["strokeStyle"] as? StrokeStyleType {
            shape.strokeStyle = strokeStyle
        }
        if let fillColor = attrs["fillColor"] as? Color {
            shape.fillColor = fillColor
        }
        if let fillOpacity = attrs["fillOpacity"] as? CGFloat {
            shape.fillOpacity = fillOpacity
        }

        viewModel.addObject(shape)
    }

    public func renderPreview(
        start: CGPoint,
        current: CGPoint,
        viewModel: CanvasViewModel
    ) -> AnyView {
        let (position, size) = calculateFrame(start: start, end: current, shiftHeld: false)
        guard size.width >= 1 && size.height >= 1 else {
            return AnyView(EmptyView())
        }

        // Get tool attributes for preview
        let attrs = viewModel.currentToolAttributes
        let strokeColor = attrs["strokeColor"] as? Color ?? .black
        let strokeWidth = attrs["strokeWidth"] as? CGFloat ?? 2.0
        let fillColor = attrs["fillColor"] as? Color ?? .white
        let fillOpacity = attrs["fillOpacity"] as? CGFloat ?? 1.0

        // Render preview with tool attributes
        return AnyView(
            Path { path in
                path.addRect(CGRect(origin: .zero, size: size))
            }
            .stroke(strokeColor, lineWidth: strokeWidth)
            .background(fillColor.opacity(fillOpacity))
            .frame(width: size.width, height: size.height)
            .position(x: position.x + size.width/2, y: position.y + size.height/2)
        )
    }
}
```

---

## Part 3: Selection Attribute Extraction

### 3.1 Extract Current Selection Attributes

```swift
// Add to AnotarCanvas/ViewModels/CanvasViewModel.swift

// MARK: - Selection Attribute Extraction

/// Extract common attributes from selected objects
/// Returns only attributes that are identical across all selected objects
/// Missing keys indicate mixed values (useful for "Mixed" state in UI)
public func getSelectionAttributes() -> ObjectAttributes {
    guard !selectedIds.isEmpty else { return [:] }

    let objects = selectedObjects
    guard !objects.isEmpty else { return [:] }

    var result: ObjectAttributes = [:]

    // Extract from first object as baseline
    if let first = objects.first {
        // Stroke properties
        if first.isStrokable {
            if let shape = first.asShapeObject {
                result["strokeColor"] = shape.strokeColor
                result["strokeWidth"] = shape.strokeWidth
                result["strokeStyle"] = shape.strokeStyle
            } else if let line = first.asLineObject {
                result["strokeColor"] = line.strokeColor
                result["strokeWidth"] = line.strokeWidth
                result["strokeStyle"] = line.strokeStyle
            }
        }

        // Fill properties
        if first.isFillable, let shape = first.asShapeObject {
            result["fillColor"] = shape.fillColor
            result["fillOpacity"] = shape.fillOpacity
        }

        // Text properties
        if first.hasTextContent {
            if let textObj = first.asTextObject {
                result["textColor"] = textObj.color
                result["fontSize"] = textObj.fontSize
            } else if let shape = first.asShapeObject {
                result["textColor"] = shape.textColor
                result["fontSize"] = shape.fontSize
            }
        }
    }

    // Compare with remaining objects, remove mismatched attributes
    for obj in objects.dropFirst() {
        // Check stroke
        if obj.isStrokable {
            if let shape = obj.asShapeObject {
                if result["strokeColor"] as? Color != shape.strokeColor {
                    result.removeValue(forKey: "strokeColor")
                }
                if result["strokeWidth"] as? CGFloat != shape.strokeWidth {
                    result.removeValue(forKey: "strokeWidth")
                }
                if result["strokeStyle"] as? StrokeStyleType != shape.strokeStyle {
                    result.removeValue(forKey: "strokeStyle")
                }
            } else if let line = obj.asLineObject {
                if result["strokeColor"] as? Color != line.strokeColor {
                    result.removeValue(forKey: "strokeColor")
                }
                if result["strokeWidth"] as? CGFloat != line.strokeWidth {
                    result.removeValue(forKey: "strokeWidth")
                }
            }
        }

        // Check fill
        if obj.isFillable, let shape = obj.asShapeObject {
            if result["fillColor"] as? Color != shape.fillColor {
                result.removeValue(forKey: "fillColor")
            }
            if result["fillOpacity"] as? CGFloat != shape.fillOpacity {
                result.removeValue(forKey: "fillOpacity")
            }
        }

        // Check text
        if obj.hasTextContent {
            if let textObj = obj.asTextObject {
                if result["textColor"] as? Color != textObj.color {
                    result.removeValue(forKey: "textColor")
                }
                if result["fontSize"] as? CGFloat != textObj.fontSize {
                    result.removeValue(forKey: "fontSize")
                }
            } else if let shape = obj.asShapeObject {
                if result["textColor"] as? Color != shape.textColor {
                    result.removeValue(forKey: "textColor")
                }
                if result["fontSize"] as? CGFloat != shape.fontSize {
                    result.removeValue(forKey: "fontSize")
                }
            }
        }
    }

    return result
}
```

### 3.2 Z-Order Methods

```swift
// Add to AnotarCanvas/ViewModels/CanvasViewModel.swift

// MARK: - Z-Order Actions

public func bringToFront() {
    guard !selectedIds.isEmpty else { return }
    let maxZ = objects.map { $0.zIndex }.max() ?? 0
    var offset = 1
    for id in selectedIds.sorted(by: {
        objectIndex(withId: $0)! < objectIndex(withId: $1)!
    }) {
        guard let index = objectIndex(withId: id) else { continue }
        var obj = objects[index]
        obj.zIndex = maxZ + offset
        objects[index] = obj
        offset += 1
    }
    nextZIndex = maxZ + offset
    sortObjectsByZIndex()
}

public func sendToBack() {
    guard !selectedIds.isEmpty else { return }
    let minZ = objects.map { $0.zIndex }.min() ?? 0
    var offset = 0
    for id in selectedIds.sorted(by: {
        objectIndex(withId: $0)! < objectIndex(withId: $1)!
    }) {
        guard let index = objectIndex(withId: id) else { continue }
        var obj = objects[index]
        obj.zIndex = minZ - selectedIds.count + offset
        objects[index] = obj
        offset += 1
    }
    sortObjectsByZIndex()
}

public func bringForward() {
    guard !selectedIds.isEmpty else { return }
    let sorted = selectedIds.sorted { id1, id2 in
        (object(withId: id1)?.zIndex ?? 0) > (object(withId: id2)?.zIndex ?? 0)
    }
    for id in sorted {
        guard let index = objectIndex(withId: id) else { continue }
        var obj = objects[index]
        obj.zIndex += 1
        objects[index] = obj
    }
    sortObjectsByZIndex()
}

public func sendBackward() {
    guard !selectedIds.isEmpty else { return }
    let sorted = selectedIds.sorted { id1, id2 in
        (object(withId: id1)?.zIndex ?? 0) < (object(withId: id2)?.zIndex ?? 0)
    }
    for id in sorted {
        guard let index = objectIndex(withId: id) else { continue }
        var obj = objects[index]
        obj.zIndex = max(0, obj.zIndex - 1)
        objects[index] = obj
    }
    sortObjectsByZIndex()
}
```

### 3.3 Selection Capabilities

```swift
// AnotarCanvas/Models/SelectionCapabilities.swift

import Foundation

public struct SelectionCapabilities {
    public let canStroke: Bool
    public let canFill: Bool
    public let canEditText: Bool
    public let canResize: Bool
    public let canRotate: Bool
    public let objectCount: Int

    public static func from(objects: [AnyCanvasObject]) -> SelectionCapabilities {
        guard !objects.isEmpty else {
            return SelectionCapabilities(
                canStroke: false,
                canFill: false,
                canEditText: false,
                canResize: false,
                canRotate: false,
                objectCount: 0
            )
        }

        return SelectionCapabilities(
            canStroke: objects.allSatisfy { $0.isStrokable },
            canFill: objects.allSatisfy { $0.isFillable },
            canEditText: objects.allSatisfy { $0.hasTextContent },
            canResize: true,
            canRotate: true,
            objectCount: objects.count
        )
    }
}
```

```swift
// Add to AnotarCanvas/ViewModels/CanvasViewModel.swift

public var selectionCapabilities: SelectionCapabilities {
    SelectionCapabilities.from(objects: selectedObjects)
}
```

---

## Part 4: Sub-Toolbar UI

### 4.1 Sub-Toolbar View

```swift
// Annota/Views/SubToolbarView.swift

import SwiftUI
import AnotarCanvas

struct SubToolbarView: View {
    @ObservedObject var viewModel: CanvasViewModel
    @ObservedObject var toolRegistry: ToolRegistry

    var body: some View {
        HStack(spacing: 16) {
            if viewModel.selectionState.hasSelection {
                selectionControls
            } else {
                toolControls
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Selection Controls (shows current object attributes)

    @ViewBuilder
    private var selectionControls: some View {
        let capabilities = viewModel.selectionCapabilities
        let attrs = viewModel.getSelectionAttributes()

        Text("\(capabilities.objectCount) selected")
            .font(.caption)
            .foregroundColor(.secondary)

        Divider().frame(height: 20)

        if capabilities.canStroke {
            strokeControls(attributes: attrs)
            Divider().frame(height: 20)
        }

        if capabilities.canFill {
            fillControls(attributes: attrs)
            Divider().frame(height: 20)
        }

        zOrderControls()

        Spacer()

        Button(action: { viewModel.deleteSelected() }) {
            Image(systemName: "trash")
                .foregroundColor(.red)
        }
        .buttonStyle(.plain)
        .help("Delete")
    }

    @ViewBuilder
    private func strokeControls(attributes: ObjectAttributes) -> some View {
        Label("Stroke", systemImage: "pencil.line")
            .font(.caption)
            .foregroundColor(.secondary)

        // Color picker - shows current or "Mixed"
        if let strokeColor = attributes["strokeColor"] as? Color {
            ColorPicker("", selection: Binding(
                get: { strokeColor },
                set: { viewModel.updateSelected(["strokeColor": $0]) }
            ))
            .labelsHidden()
            .frame(width: 40)
        } else {
            Text("Mixed")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 40)
        }

        // Width stepper - shows current or "Mixed"
        if let strokeWidth = attributes["strokeWidth"] as? CGFloat {
            Stepper(value: Binding(
                get: { strokeWidth },
                set: { viewModel.updateSelected(["strokeWidth": $0]) }
            ), in: 0...20, step: 0.5) {
                Text("\(Int(strokeWidth))pt")
                    .font(.caption)
                    .frame(width: 30)
            }
        } else {
            Text("Mixed")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func fillControls(attributes: ObjectAttributes) -> some View {
        Label("Fill", systemImage: "paintbrush.fill")
            .font(.caption)
            .foregroundColor(.secondary)

        if let fillColor = attributes["fillColor"] as? Color {
            ColorPicker("", selection: Binding(
                get: { fillColor },
                set: { viewModel.updateSelected(["fillColor": $0]) }
            ))
            .labelsHidden()
            .frame(width: 40)
        } else {
            Text("Mixed")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 40)
        }

        if let fillOpacity = attributes["fillOpacity"] as? CGFloat {
            Slider(value: Binding(
                get: { fillOpacity },
                set: { viewModel.updateSelected(["fillOpacity": $0]) }
            ), in: 0...1)
            .frame(width: 80)

            Text("\(Int(fillOpacity * 100))%")
                .font(.caption)
                .frame(width: 35)
        } else {
            Text("Mixed")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func zOrderControls() -> some View {
        HStack(spacing: 4) {
            Button(action: { viewModel.bringToFront() }) {
                Image(systemName: "square.3.layers.3d.top.filled")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .help("Bring to Front")

            Button(action: { viewModel.sendToBack() }) {
                Image(systemName: "square.3.layers.3d.bottom.filled")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .help("Send to Back")
        }
    }

    // MARK: - Tool Controls (shows and edits tool attributes)

    @ViewBuilder
    private var toolControls: some View {
        let tool = toolRegistry.tool(for: viewModel.selectedTool)
        let attrs = viewModel.currentToolAttributes

        Text("Tool: \(tool?.name ?? viewModel.selectedTool.id)")
            .font(.caption)
            .foregroundColor(.secondary)

        Divider().frame(height: 20)

        // Shape and annotation tools
        if tool?.category == .shape || tool?.category == .annotation {
            Label("Stroke", systemImage: "pencil.line")
                .font(.caption)
                .foregroundColor(.secondary)

            ColorPicker("", selection: Binding(
                get: { attrs["strokeColor"] as? Color ?? .black },
                set: { viewModel.updateToolAttribute(key: "strokeColor", value: $0) }
            ))
            .labelsHidden()
            .frame(width: 40)

            Stepper(value: Binding(
                get: { attrs["strokeWidth"] as? CGFloat ?? 2.0 },
                set: { viewModel.updateToolAttribute(key: "strokeWidth", value: $0) }
            ), in: 0...20, step: 0.5) {
                Text("\(Int(attrs["strokeWidth"] as? CGFloat ?? 2.0))pt")
                    .font(.caption)
                    .frame(width: 30)
            }

            Divider().frame(height: 20)

            if tool?.category == .shape {
                Label("Fill", systemImage: "paintbrush.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ColorPicker("", selection: Binding(
                    get: { attrs["fillColor"] as? Color ?? .white },
                    set: { viewModel.updateToolAttribute(key: "fillColor", value: $0) }
                ))
                .labelsHidden()
                .frame(width: 40)

                Slider(value: Binding(
                    get: { attrs["fillOpacity"] as? CGFloat ?? 1.0 },
                    set: { viewModel.updateToolAttribute(key: "fillOpacity", value: $0) }
                ), in: 0...1)
                .frame(width: 80)

                Text("\(Int((attrs["fillOpacity"] as? CGFloat ?? 1.0) * 100))%")
                    .font(.caption)
                    .frame(width: 35)
            }
        }
        // Line and arrow tools
        else if tool?.category == .drawing {
            Label("Line", systemImage: "pencil.line")
                .font(.caption)
                .foregroundColor(.secondary)

            ColorPicker("", selection: Binding(
                get: { attrs["strokeColor"] as? Color ?? .black },
                set: { viewModel.updateToolAttribute(key: "strokeColor", value: $0) }
            ))
            .labelsHidden()
            .frame(width: 40)

            Stepper(value: Binding(
                get: { attrs["strokeWidth"] as? CGFloat ?? 2.0 },
                set: { viewModel.updateToolAttribute(key: "strokeWidth", value: $0) }
            ), in: 0...20, step: 0.5) {
                Text("\(Int(attrs["strokeWidth"] as? CGFloat ?? 2.0))pt")
                    .font(.caption)
                    .frame(width: 30)
            }
        }

        Spacer()
    }
}
```

### 4.2 Integration into ContentView

```swift
// Annota/Views/ContentView.swift

struct ContentView: View {
    @StateObject private var viewModel = CanvasViewModel()
    @StateObject private var toolRegistry = ToolRegistry.shared

    var body: some View {
        VStack(spacing: 0) {
            // Main toolbar
            ToolbarView(viewModel: viewModel, toolRegistry: toolRegistry)

            Divider()

            // Sub-toolbar (context-sensitive)
            SubToolbarView(viewModel: viewModel, toolRegistry: toolRegistry)

            Divider()

            // Canvas
            CanvasView(viewModel: viewModel)
        }
    }
}
```

---

## Complete Data Flow

### Flow 1: Creating Objects with Tool Attributes

```
1. User selects Rectangle tool
2. Sub-toolbar loads toolAttributes["rectangle"]
   - Shows: blue stroke, 3pt width, white fill
3. User changes stroke width to 5pt in sub-toolbar
4. updateToolAttribute() updates toolAttributes["rectangle"]["strokeWidth"] = 5.0
5. User drags to create rectangle
6. renderPreview() reads currentToolAttributes
   - Preview shows: blue 5pt stroke ✅
7. handleDragEnded() reads currentToolAttributes
   - Creates object with: blue 5pt stroke ✅
```

### Flow 2: Editing Selected Objects

```
1. User selects red 2pt rectangle
2. getSelectionAttributes() extracts current values
   - Returns: ["strokeColor": red, "strokeWidth": 2.0]
3. Sub-toolbar displays current values
   - ColorPicker shows red
   - Stepper shows 2pt
4. User changes to green in sub-toolbar
5. Binding calls updateSelected(["strokeColor": green])
6. Object updated via .applying() method
7. @Published triggers → UI refreshes
8. Sub-toolbar re-reads, now shows green ✅
```

### Flow 3: Multiple Selection (Mixed Values)

```
1. User selects 3 rectangles (red, blue, red)
2. getSelectionAttributes() detects mismatch
   - strokeColor differs → removed from result
   - Returns: ["strokeWidth": 2.0] (only common values)
3. Sub-toolbar shows:
   - "Mixed" for stroke color
   - "2pt" for stroke width
4. User picks green
5. All 3 rectangles updated to green ✅
```

---

## Implementation Checklist

### Framework Layer (AnotarCanvas)

**Batch Update System:**
- [ ] Create `ObjectAttributes.swift` with type alias and keys
- [ ] Add `_mutate` and `_rebuild` closures to `AnyCanvasObject`
- [ ] Implement `applying(_ attributes:)` method
- [ ] Implement `applyAttributesGeneric<T>()` helper

**ViewModel Methods:**
- [ ] Add `updateObject(_:attributes:)` method
- [ ] Add `updateSelected(_:)` method
- [ ] Add `toolAttributes` property
- [ ] Add `currentToolAttributes` computed property
- [ ] Add `updateToolAttribute(key:value:)` method
- [ ] Add `getSelectionAttributes()` method
- [ ] Add `selectionCapabilities` computed property

**Z-Order Methods:**
- [ ] Implement `bringToFront()`
- [ ] Implement `sendToBack()`
- [ ] Implement `bringForward()`
- [ ] Implement `sendBackward()`

**Models:**
- [ ] Create `SelectionCapabilities.swift`

**Tool Updates:**
- [ ] Update `BaseShapeTool.handleDragEnded()` to use tool attributes
- [ ] Update `BaseShapeTool.renderPreview()` to use tool attributes
- [ ] Update `LineTool` to use tool attributes
- [ ] Update `ArrowTool` to use tool attributes
- [ ] Update `TextTool` to use tool attributes

### Application Layer (Annota)

**UI Components:**
- [ ] Create `SubToolbarView.swift`
- [ ] Implement `selectionControls`
- [ ] Implement `toolControls`
- [ ] Handle "Mixed" state display

**Integration:**
- [ ] Add `SubToolbarView` to `ContentView`
- [ ] Test attribute persistence
- [ ] Test preview rendering
- [ ] Test multi-selection

---

## Key Benefits

✅ **Type-Erased Batch Updates** - No hardcoded type dispatch
✅ **Tool Memory** - Each tool remembers settings
✅ **Live Preview** - Preview shows final attributes
✅ **Current State Display** - Shows actual object values
✅ **Mixed State Handling** - Multi-selection with different values
✅ **Professional UX** - Like Figma, Sketch, Adobe tools
✅ **Plugin-Friendly** - Works with any CanvasObject type

---

## Usage Examples

```swift
// Batch update multiple attributes
viewModel.updateSelected([
    "strokeColor": Color.blue,
    "strokeWidth": 3.0,
    "fillOpacity": 0.5
])

// Update tool attributes (remembered for next use)
viewModel.updateToolAttribute(key: "strokeColor", value: Color.red)

// Get current selection attributes (handles mixed values)
let attrs = viewModel.getSelectionAttributes()
if let color = attrs["strokeColor"] as? Color {
    // All selected objects have same color
} else {
    // Mixed colors - show "Mixed" in UI
}

// Z-order operations
viewModel.bringToFront()
viewModel.sendToBack()
```

This provides a complete, professional editing experience! 🎨
