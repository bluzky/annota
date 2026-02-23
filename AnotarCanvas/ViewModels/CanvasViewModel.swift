//
//  CanvasViewModel.swift
//  AnotarCanvas
//
//  Created by Flex on 12/11/25.
//

import SwiftUI
import Combine

@MainActor
public class CanvasViewModel: ObservableObject {
    public init() {}

    // MARK: - Unified Object Storage

    /// Primary storage for all canvas objects, sorted by zIndex
    @Published public private(set) var objects: [AnyCanvasObject] = []

    /// Next available zIndex for new objects
    private var nextZIndex: Int = 0

    // MARK: - Tool State

    @Published public var selectedTool: DrawingTool = .select {
        didSet {
            // Exit text editing when switching tools
            deselectAll()
        }
    }

    /// Multi-selection state
    @Published public var selectionState = SelectionState()

    /// Backward compatibility: returns the single selected ID if exactly one object is selected
    public var selectedObjectId: UUID? {
        get { selectionState.singleSelectedId }
        set {
            if let id = newValue {
                selectionState.select(id)
            } else {
                selectionState.clear()
            }
        }
    }
    @Published public var activeTextSize: CGFloat = 16
    @Published public var activeColor: Color = .black

    // MARK: - Tool Attribute State

    /// Current tool attributes — set by the application layer, read by tools.
    /// The app layer is responsible for persisting/restoring these when tools change.
    @Published public var currentToolAttributes: ObjectAttributes = [:]

    /// Update a specific attribute within currentToolAttributes
    public func updateToolAttribute(key: String, value: Any) {
        currentToolAttributes[key] = value
    }

    /// Update a custom attribute within the customAttributes namespace
    public func updateCustomToolAttribute(key: String, value: Any) {
        var customAttrs = (currentToolAttributes[ObjectAttributes.customAttributes] as? [String: Any]) ?? [:]
        customAttrs[key] = value
        currentToolAttributes[ObjectAttributes.customAttributes] = customAttrs
    }

    /// Get a custom attribute value with a default
    public func getCustomToolAttribute<T>(key: String, default defaultValue: T) -> T {
        let customAttrs = (currentToolAttributes[ObjectAttributes.customAttributes] as? [String: Any]) ?? [:]
        return customAttrs[key] as? T ?? defaultValue
    }

    /// Get a custom attribute value (optional)
    public func getCustomToolAttribute<T>(key: String) -> T? {
        let customAttrs = (currentToolAttributes[ObjectAttributes.customAttributes] as? [String: Any]) ?? [:]
        return customAttrs[key] as? T
    }

    // MARK: - Viewport State

    @Published public var viewport = ViewportState()

    // MARK: - Transient Drag State

    @Published public var dragStartPoint: CGPoint?
    @Published public var currentDragPoint: CGPoint?

    /// Current canvas viewport size (updated by CanvasView on geometry changes).
    /// Stored here so closures that outlive a SwiftUI body evaluation (e.g. the
    /// key-event monitor) always read the current value instead of a stale capture.
    public var canvasSize: CGSize = .zero

    // MARK: - Computed Properties

    /// Check if any object is currently being edited
    public var isAnyObjectEditing: Bool {
        objects.contains { $0.isEditing }
    }

    /// Get the currently editing object's ID and contains closure, if any
    public func editingObject() -> (id: UUID, contains: (CGPoint) -> Bool)? {
        guard let wrapper = objects.first(where: { $0.isEditing }) else { return nil }
        return (wrapper.id, { wrapper.contains($0) })
    }

    /// Get the capabilities of the current selection
    public var selectionCapabilities: SelectionCapabilities {
        SelectionCapabilities.from(objects: selectedObjects)
    }

    // MARK: - Object Retrieval

    /// Find object by ID
    public func object(withId id: UUID) -> AnyCanvasObject? {
        objects.first { $0.id == id }
    }

    /// Find object index by ID
    private func objectIndex(withId id: UUID) -> Int? {
        objects.firstIndex { $0.id == id }
    }

    // MARK: - Add Objects

    /// Generic method to add any CanvasObject to the canvas.
    /// Assigns the next zIndex and appends to the objects array.
    @discardableResult
    public func addObject<T: CanvasObject>(_ object: T) -> UUID {
        var obj = object
        obj.zIndex = nextZIndex
        nextZIndex += 1
        objects.append(AnyCanvasObject(obj))
        sortObjectsByZIndex()
        return obj.id
    }

    @discardableResult
    public func addImageObject(imageData: Data, imageSize: CGSize, at position: CGPoint, maxSize: CGSize = .zero) -> UUID {
        var size = imageSize.width > 0 && imageSize.height > 0
            ? imageSize
            : CGSize(width: 100, height: 100)

        // Cap to maxSize (viewport canvas dimensions) while preserving aspect ratio
        if maxSize.width > 0 && maxSize.height > 0 {
            size = ImageObject.fittingSize(for: size, maxDimension: min(maxSize.width, maxSize.height))
        }

        let aspectRatio = size.width / size.height
        // Position is the center point — convert to top-left origin
        let origin = CGPoint(
            x: position.x - size.width / 2,
            y: position.y - size.height / 2
        )
        var imageObj = ImageObject(
            position: origin,
            size: size,
            imageData: imageData,
            aspectRatio: aspectRatio
        )
        imageObj.zIndex = nextZIndex
        nextZIndex += 1

        objects.append(AnyCanvasObject(imageObj))
        sortObjectsByZIndex()
        return imageObj.id
    }

    // MARK: - Remove Objects

    /// Remove object by ID
    public func removeObject(withId id: UUID) {
        objects.removeAll { $0.id == id }
    }

    // MARK: - Batch Attribute Updates

    /// Update attributes on a specific object using type-erased mutation
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
                    result[ObjectAttributes.strokeColor] = shape.strokeColor
                    result[ObjectAttributes.strokeWidth] = shape.strokeWidth
                    result[ObjectAttributes.strokeStyle] = shape.strokeStyle
                } else if let line = first.asLineObject {
                    result[ObjectAttributes.strokeColor] = line.strokeColor
                    result[ObjectAttributes.strokeWidth] = line.strokeWidth
                    result[ObjectAttributes.strokeStyle] = line.strokeStyle
                }
            }

            // Fill properties
            if first.isFillable, let shape = first.asShapeObject {
                result[ObjectAttributes.fillColor] = shape.fillColor
                result[ObjectAttributes.fillOpacity] = shape.fillOpacity
            }

            // Text properties
            if first.hasTextContent {
                if let textObj = first.asTextObject {
                    result[ObjectAttributes.textColor] = textObj.color
                    result[ObjectAttributes.fontSize] = textObj.fontSize
                    result[ObjectAttributes.fontFamily] = textObj.textAttributes.fontFamily
                } else if let shape = first.asShapeObject {
                    result[ObjectAttributes.textColor] = shape.textAttributes.textColor.color
                    result[ObjectAttributes.fontSize] = shape.textAttributes.fontSize
                    result[ObjectAttributes.fontFamily] = shape.textAttributes.fontFamily
                }
            }
        }

        // Compare with remaining objects, remove mismatched attributes
        for obj in objects.dropFirst() {
            // Check stroke
            if obj.isStrokable {
                if let shape = obj.asShapeObject {
                    if result[ObjectAttributes.strokeColor] as? Color != shape.strokeColor {
                        result.removeValue(forKey: ObjectAttributes.strokeColor)
                    }
                    if result[ObjectAttributes.strokeWidth] as? CGFloat != shape.strokeWidth {
                        result.removeValue(forKey: ObjectAttributes.strokeWidth)
                    }
                    if result[ObjectAttributes.strokeStyle] as? StrokeStyleType != shape.strokeStyle {
                        result.removeValue(forKey: ObjectAttributes.strokeStyle)
                    }
                } else if let line = obj.asLineObject {
                    if result[ObjectAttributes.strokeColor] as? Color != line.strokeColor {
                        result.removeValue(forKey: ObjectAttributes.strokeColor)
                    }
                    if result[ObjectAttributes.strokeWidth] as? CGFloat != line.strokeWidth {
                        result.removeValue(forKey: ObjectAttributes.strokeWidth)
                    }
                    if result[ObjectAttributes.strokeStyle] as? StrokeStyleType != line.strokeStyle {
                        result.removeValue(forKey: ObjectAttributes.strokeStyle)
                    }
                }
            }

            // Check fill
            if obj.isFillable, let shape = obj.asShapeObject {
                if result[ObjectAttributes.fillColor] as? Color != shape.fillColor {
                    result.removeValue(forKey: ObjectAttributes.fillColor)
                }
                if result[ObjectAttributes.fillOpacity] as? CGFloat != shape.fillOpacity {
                    result.removeValue(forKey: ObjectAttributes.fillOpacity)
                }
            }

            // Check text
            if obj.hasTextContent {
                if let textObj = obj.asTextObject {
                    if result[ObjectAttributes.textColor] as? Color != textObj.color {
                        result.removeValue(forKey: ObjectAttributes.textColor)
                    }
                    if result[ObjectAttributes.fontSize] as? CGFloat != textObj.fontSize {
                        result.removeValue(forKey: ObjectAttributes.fontSize)
                    }
                    if result[ObjectAttributes.fontFamily] as? String != textObj.textAttributes.fontFamily {
                        result.removeValue(forKey: ObjectAttributes.fontFamily)
                    }
                } else if let shape = obj.asShapeObject {
                    if result[ObjectAttributes.textColor] as? Color != shape.textAttributes.textColor.color {
                        result.removeValue(forKey: ObjectAttributes.textColor)
                    }
                    if result[ObjectAttributes.fontSize] as? CGFloat != shape.textAttributes.fontSize {
                        result.removeValue(forKey: ObjectAttributes.fontSize)
                    }
                    if result[ObjectAttributes.fontFamily] as? String != shape.textAttributes.fontFamily {
                        result.removeValue(forKey: ObjectAttributes.fontFamily)
                    }
                }
            }
        }

        // Extract custom attributes if all selected objects support customization
        if !objects.isEmpty {
            // Try to get custom attributes from first object
            if let firstCustomizable = objects.first?.asType(LineObject.self) as? CustomizableObject ??
               objects.first?.asType(ShapeObject.self) as? CustomizableObject {
                var customAttrs = firstCustomizable.getCustomAttributes()

                // Compare with remaining objects
                for obj in objects.dropFirst() {
                    if let customizable = obj.asType(LineObject.self) as? CustomizableObject ??
                       obj.asType(ShapeObject.self) as? CustomizableObject {
                        let objCustomAttrs = customizable.getCustomAttributes()

                        // Remove keys that don't match
                        for key in customAttrs.keys {
                            if !areEqual(customAttrs[key], objCustomAttrs[key]) {
                                customAttrs.removeValue(forKey: key)
                            }
                        }
                    } else {
                        // If any object doesn't support customization, clear all custom attrs
                        customAttrs.removeAll()
                        break
                    }
                }

                if !customAttrs.isEmpty {
                    result[ObjectAttributes.customAttributes] = customAttrs
                }
            }
        }

        return result
    }

    /// Helper to compare Any values for attribute matching
    private func areEqual(_ lhs: Any?, _ rhs: Any?) -> Bool {
        guard let lhs = lhs, let rhs = rhs else { return lhs == nil && rhs == nil }

        // Handle common types
        if let l = lhs as? String, let r = rhs as? String { return l == r }
        if let l = lhs as? CGFloat, let r = rhs as? CGFloat { return l == r }
        if let l = lhs as? Int, let r = rhs as? Int { return l == r }
        if let l = lhs as? Bool, let r = rhs as? Bool { return l == r }

        // Add more type comparisons as needed
        return false
    }

    // MARK: - Update Objects

    /// Generic update: extracts an object of type T, applies mutation, and stores it back
    public func updateObject<T: CanvasObject>(
        withId id: UUID,
        as _: T.Type,
        update: (inout T) -> Void
    ) {
        guard let index = objectIndex(withId: id),
              var obj = objects[index].asType(T.self) else { return }
        update(&obj)
        objects[index] = AnyCanvasObject(obj)
    }

    // MARK: - Hit Testing & Selection

    public func selectObject(at point: CGPoint) -> UUID? {
        // Check objects in reverse z-order (highest zIndex first)
        for obj in objects.reversed() {
            if obj.contains(point) {
                return obj.id
            }
        }
        return nil
    }

    public func startEditing(objectId: UUID) {
        guard let index = objectIndex(withId: objectId) else { return }
        guard objects[index].hasTextContent else { return }
        mutateTextContent(at: index) { $0.isEditing = true }
        selectedObjectId = objectId
    }

    public func updateText(objectId: UUID, text: String) {
        guard let index = objectIndex(withId: objectId) else { return }
        guard objects[index].hasTextContent else { return }
        mutateTextContent(at: index) { $0.text = text }
    }

    public func deselectAll() {
        selectionState.clear()
        endAllEditing()
    }

    // MARK: - Move Objects

    public func moveObject(id: UUID, by offset: CGSize) {
        guard let index = objectIndex(withId: id) else { return }
        applyGeometry(at: index) {
            $0.position.x += offset.width
            $0.position.y += offset.height
        }
    }

    /// Update rotation for an object
    public func updateObjectRotation(id: UUID, rotation: CGFloat) {
        guard let index = objectIndex(withId: id) else { return }
        applyGeometry(at: index) { $0.rotation = rotation }
    }

    /// Update position and rotation for an object (used by group rotation)
    public func updateObjectPositionAndRotation(id: UUID, position: CGPoint, rotation: CGFloat) {
        guard let index = objectIndex(withId: id) else { return }
        applyGeometry(at: index) { $0.position = position; $0.rotation = rotation }
    }

    /// Update position and size for an object (used by resize)
    public func updateObjectFrame(id: UUID, position: CGPoint, size: CGSize) {
        guard let index = objectIndex(withId: id) else { return }
        applyGeometry(at: index) { $0.position = position; $0.size = size }
    }

    /// Apply a geometry mutation to whichever concrete type lives at `index`.
    /// This is the single place that handles the four-way type dispatch so callers
    /// don't have to repeat it.  The closure receives a mutable reference to a thin
    /// `ObjectGeometry` value; changes are written back into `objects[index]`.
    private func applyGeometry(at index: Int, mutation: (inout ObjectGeometry) -> Void) {
        func apply<T: CanvasObject>(_ obj: T?) {
            guard var obj = obj else { return }
            var geo = ObjectGeometry(position: obj.position, size: obj.size, rotation: obj.rotation)
            mutation(&geo)
            obj.position = geo.position; obj.size = geo.size; obj.rotation = geo.rotation
            objects[index] = AnyCanvasObject(obj)
        }
        // Try each concrete type; first match wins
        if objects[index].asTextObject != nil { apply(objects[index].asTextObject) }
        else if objects[index].asShapeObject != nil { apply(objects[index].asShapeObject) }
        else if objects[index].asLineObject != nil { apply(objects[index].asLineObject) }
        else if objects[index].asImageObject != nil { apply(objects[index].asImageObject) }
    }

    public func selectObjectOnly(id: UUID) {
        selectionState.select(id)
        endAllEditing()
    }

    /// Toggle selection of an object (for shift+click)
    public func toggleObjectSelection(id: UUID) {
        // End any text editing first
        endAllEditing()
        selectionState.toggleSelection(id)
    }

    /// Select multiple objects (for marquee selection)
    public func selectMultiple(ids: Set<UUID>) {
        endAllEditing()
        selectionState.selectMultiple(ids)
    }

    /// Add multiple objects to selection (for shift+marquee)
    public func addMultipleToSelection(ids: Set<UUID>) {
        endAllEditing()
        selectionState.addMultipleToSelection(ids)
    }

    /// Check if an object is currently selected
    public func isSelected(_ id: UUID) -> Bool {
        selectionState.isSelected(id)
    }

    /// Get all selected object IDs
    public var selectedIds: Set<UUID> {
        selectionState.selectedIds
    }

    /// Get the selection box for currently selected objects
    public var selectionBox: SelectionBox? {
        guard selectionState.hasSelection else { return nil }

        let selectedObjects = objects.filter { selectionState.isSelected($0.id) }
        return SelectionBox.from(objects: selectedObjects)
    }

    /// Get selected objects as an array
    public var selectedObjects: [AnyCanvasObject] {
        objects.filter { selectionState.isSelected($0.id) }
    }

    /// Whether all selected objects use control points (no selection box needed)
    public var isControlPointOnlySelection: Bool {
        guard selectionState.hasSelection else { return false }
        return selectedObjects.allSatisfy { $0.usesControlPoints }
    }

    /// End all text editing without clearing selection
    private func endAllEditing() {
        // Collect IDs of text objects that are empty and should be removed
        var idsToRemove: [UUID] = []
        for index in objects.indices where objects[index].isEditing {
            // Check if this is a TextObject with empty text
            if let textObj = objects[index].asTextObject,
               textObj.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                idsToRemove.append(objects[index].id)
            } else {
                mutateTextContent(at: index) { $0.isEditing = false }
            }
        }
        // Remove empty text objects
        for id in idsToRemove {
            objects.removeAll { $0.id == id }
        }
    }

    /// Apply a mutation to the TextContentObject (TextObject or ShapeObject) at the given index.
    /// Centralises the two-way dispatch so callers don't repeat it.
    private func mutateTextContent(at index: Int, mutation: (inout TextContentProxy) -> Void) {
        if var obj = objects[index].asTextObject {
            var proxy = TextContentProxy(text: obj.text, isEditing: obj.isEditing)
            mutation(&proxy)
            obj.text = proxy.text; obj.isEditing = proxy.isEditing
            objects[index] = AnyCanvasObject(obj)
        } else if var obj = objects[index].asShapeObject {
            var proxy = TextContentProxy(text: obj.text, isEditing: obj.isEditing)
            mutation(&proxy)
            obj.text = proxy.text; obj.isEditing = proxy.isEditing
            objects[index] = AnyCanvasObject(obj)
        }
    }

    /// Find all objects within a marquee rectangle
    public func objectsInRect(_ rect: CGRect) -> Set<UUID> {
        var ids = Set<UUID>()
        for obj in objects {
            if obj.intersectsRect(rect) {
                ids.insert(obj.id)
            }
        }
        return ids
    }

    /// Move all selected objects by offset
    public func moveSelectedObjects(by offset: CGSize) {
        for id in selectionState.selectedIds {
            moveObject(id: id, by: offset)
        }
    }

    // MARK: - Clipboard Operations

    public func copySelection() {
        let selected = selectedObjects
        guard !selected.isEmpty else { return }
        let codable = selected.compactMap { CodableCanvasObject.from($0) }
        ClipboardService.copyObjects(codable)
    }

    public func cutSelection() {
        copySelection()
        deleteSelected()
    }

    public func pasteFromClipboard(viewportSize: CGSize = .zero) {
        // Try internal canvas clipboard first
        if let codableObjects = ClipboardService.pasteObjects(), !codableObjects.isEmpty {
            pasteCanvasObjects(codableObjects, viewportSize: viewportSize)
            return
        }

        // Fall back to system image clipboard
        if let (imageData, imageSize) = ClipboardService.pasteImageData() {
            let screenCenter = viewportSize.width > 0 && viewportSize.height > 0
                ? CGPoint(x: viewportSize.width / 2, y: viewportSize.height / 2)
                : CGPoint(x: 400, y: 300)
            let canvasCenter = viewport.screenToCanvas(screenCenter)
            // Convert viewport screen size to canvas units so the cap respects current zoom
            let canvasMaxSize = viewportSize.width > 0 && viewportSize.height > 0
                ? CGSize(width: viewportSize.width / viewport.scale, height: viewportSize.height / viewport.scale)
                : CGSize.zero
            let newId = addImageObject(imageData: imageData, imageSize: imageSize, at: canvasCenter, maxSize: canvasMaxSize)
            endAllEditing()
            selectionState.select(newId)
        }
    }

    private func pasteCanvasObjects(_ codableObjects: [CodableCanvasObject], viewportSize: CGSize) {
        // Compute the offset to center pasted objects in the current viewport
        let pasteOffset: CGPoint
        if viewportSize.width > 0 && viewportSize.height > 0 {
            // Find the center of the visible canvas area
            let screenCenter = CGPoint(x: viewportSize.width / 2, y: viewportSize.height / 2)
            let canvasCenter = viewport.screenToCanvas(screenCenter)

            // Build temporary objects to find their group bounding box
            var tempObjects: [AnyCanvasObject] = []
            for codable in codableObjects {
                guard let obj = codable.toAnyCanvasObject(newId: UUID(), zIndex: 0, offset: .zero) else { continue }
                tempObjects.append(obj)
            }
            var minX = CGFloat.infinity, minY = CGFloat.infinity
            var maxX = -CGFloat.infinity, maxY = -CGFloat.infinity
            for obj in tempObjects {
                let bbox = obj.boundingBox()
                minX = min(minX, bbox.minX)
                minY = min(minY, bbox.minY)
                maxX = max(maxX, bbox.maxX)
                maxY = max(maxY, bbox.maxY)
            }
            let groupCenter = CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
            pasteOffset = CGPoint(x: canvasCenter.x - groupCenter.x, y: canvasCenter.y - groupCenter.y)
        } else {
            pasteOffset = CGPoint(x: 20, y: 20)
        }

        var pastedIds = Set<UUID>()

        for codable in codableObjects {
            let newId = UUID()
            guard let newObj = codable.toAnyCanvasObject(newId: newId, zIndex: nextZIndex, offset: pasteOffset) else { continue }
            nextZIndex += 1
            objects.append(newObj)
            pastedIds.insert(newId)
        }

        sortObjectsByZIndex()
        endAllEditing()
        selectionState.selectMultiple(pastedIds)
    }

    public func deleteSelected() {
        let idsToRemove = selectionState.selectedIds
        guard !idsToRemove.isEmpty else { return }
        objects.removeAll { idsToRemove.contains($0.id) }
        selectionState.clear()
    }

    // MARK: - Z-Order Management

    /// Sort objects array by zIndex
    private func sortObjectsByZIndex() {
        objects.sort { $0.zIndex < $1.zIndex }
    }

    /// Move selected objects to the highest z-index (bring to front)
    public func bringToFront() {
        guard !selectedIds.isEmpty else { return }
        let maxZ = objects.map { $0.zIndex }.max() ?? 0
        var offset = 1
        for id in selectedIds.sorted(by: {
            guard let idx1 = objectIndex(withId: $0),
                  let idx2 = objectIndex(withId: $1) else { return false }
            return idx1 < idx2
        }) {
            guard let index = objectIndex(withId: id) else { continue }
            objects[index] = objects[index].applying([ObjectAttributes.zIndex: maxZ + offset])
            offset += 1
        }
        nextZIndex = maxZ + offset
        sortObjectsByZIndex()
    }

    /// Move selected objects to the lowest z-index (send to back)
    public func sendToBack() {
        guard !selectedIds.isEmpty else { return }
        let minZ = objects.map { $0.zIndex }.min() ?? 0
        var offset = 0
        for id in selectedIds.sorted(by: {
            guard let idx1 = objectIndex(withId: $0),
                  let idx2 = objectIndex(withId: $1) else { return false }
            return idx1 < idx2
        }) {
            guard let index = objectIndex(withId: id) else { continue }
            objects[index] = objects[index].applying([ObjectAttributes.zIndex: minZ - selectedIds.count + offset])
            offset += 1
        }
        sortObjectsByZIndex()
    }

    /// Increase z-index of selected objects by 1 (bring one layer forward)
    public func bringForward() {
        guard !selectedIds.isEmpty else { return }
        let sorted = selectedIds.sorted { id1, id2 in
            (object(withId: id1)?.zIndex ?? 0) > (object(withId: id2)?.zIndex ?? 0)
        }
        for id in sorted {
            guard let index = objectIndex(withId: id) else { continue }
            let currentZ = objects[index].zIndex
            objects[index] = objects[index].applying([ObjectAttributes.zIndex: currentZ + 1])
        }
        sortObjectsByZIndex()
    }

    /// Decrease z-index of selected objects by 1 (send one layer backward)
    public func sendBackward() {
        guard !selectedIds.isEmpty else { return }
        let sorted = selectedIds.sorted { id1, id2 in
            (object(withId: id1)?.zIndex ?? 0) < (object(withId: id2)?.zIndex ?? 0)
        }
        for id in sorted {
            guard let index = objectIndex(withId: id) else { continue }
            let currentZ = objects[index].zIndex
            objects[index] = objects[index].applying([ObjectAttributes.zIndex: max(0, currentZ - 1)])
        }
        sortObjectsByZIndex()
    }

    // MARK: - Viewport Control

    /// Pan the viewport by a delta
    public func panViewport(by delta: CGSize) {
        viewport.pan(by: delta)
    }

    /// Zoom the viewport by a factor around a point
    public func zoomViewport(by factor: CGFloat, around anchor: CGPoint) {
        viewport.zoom(by: factor, around: anchor)
    }

    /// Reset viewport to default
    public func resetViewport() {
        viewport.reset()
    }

    // MARK: - Export

    /// Render all canvas objects to an NSImage.
    /// The image covers the bounding box of all objects, with optional padding.
    /// Returns nil if there are no objects to render.
    @MainActor
    public func renderToImage(scale: CGFloat = 2.0, padding: CGFloat = 40) -> NSImage? {
        guard !objects.isEmpty else { return nil }

        // Compute tight bounding box over all objects
        var minX = CGFloat.infinity, minY = CGFloat.infinity
        var maxX = -CGFloat.infinity, maxY = -CGFloat.infinity
        for obj in objects {
            let bbox = obj.boundingBox()
            minX = min(minX, bbox.minX)
            minY = min(minY, bbox.minY)
            maxX = max(maxX, bbox.maxX)
            maxY = max(maxY, bbox.maxY)
        }
        let contentRect = CGRect(
            x: minX - padding,
            y: minY - padding,
            width: (maxX - minX) + padding * 2,
            height: (maxY - minY) + padding * 2
        )

        // Build a viewport that maps the content rect to screen coordinates starting at origin
        let exportViewport = ViewportState(
            offset: CGPoint(x: -contentRect.minX, y: -contentRect.minY),
            scale: 1.0
        )

        let exportView = CanvasExportView(objects: objects, viewport: exportViewport)
            .frame(width: contentRect.width, height: contentRect.height)

        let renderer = ImageRenderer(content: exportView)
        renderer.scale = scale
        guard let cgImage = renderer.cgImage else { return nil }
        return NSImage(cgImage: cgImage, size: contentRect.size)
    }
}

// MARK: - ObjectGeometry helper

/// Lightweight mutable bag used by CanvasViewModel.applyGeometry(at:mutation:) to
/// carry position/size/rotation across the four-way concrete-type dispatch without
/// repeating the mutation closure for each concrete type.
private struct ObjectGeometry {
    var position: CGPoint
    var size: CGSize
    var rotation: CGFloat
}

/// Lightweight mutable bag used by CanvasViewModel.mutateTextContent(at:mutation:) to
/// carry text and isEditing across the two-way TextObject/ShapeObject dispatch.
public struct TextContentProxy {
    public var text: String
    public var isEditing: Bool
}
