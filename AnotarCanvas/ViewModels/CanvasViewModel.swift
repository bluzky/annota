//
//  CanvasViewModel.swift
//  AnotarCanvas
//
//  Created by Flex on 12/11/25.
//

import SwiftUI
import Combine

// MARK: - Alignment & Distribution Actions

public enum AlignmentAction: CaseIterable {
    case left
    case right
    case top
    case bottom
    case centerHorizontal
    case centerVertical

    public var title: String {
        switch self {
        case .left: return "Align Left"
        case .right: return "Align Right"
        case .top: return "Align Top"
        case .bottom: return "Align Bottom"
        case .centerHorizontal: return "Center Horizontal"
        case .centerVertical: return "Center Vertical"
        }
    }

    public var systemImage: String {
        switch self {
        case .left: return "align.horizontal.left"
        case .right: return "align.horizontal.right"
        case .top: return "align.vertical.top"
        case .bottom: return "align.vertical.bottom"
        case .centerHorizontal: return "align.horizontal.center"
        case .centerVertical: return "align.vertical.center"
        }
    }
}

public enum DistributionAction: CaseIterable {
    case horizontal
    case vertical

    public var title: String {
        switch self {
        case .horizontal: return "Distribute Horizontally"
        case .vertical: return "Distribute Vertically"
        }
    }

    public var systemImage: String {
        switch self {
        case .horizontal: return "distribute.horizontal.center"
        case .vertical: return "distribute.vertical.center"
        }
    }
}

@MainActor
public class CanvasViewModel: ObservableObject {
    public init() {
        self.undoManager = UndoManager()
    }

    // MARK: - Undo/Redo Management

    /// Undo/redo manager for canvas actions
    public var undoManager: UndoManager?

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
    @Published public var selectionState = SelectionState() {
        didSet {
            if selectionState != oldValue {
                refreshSelectionCache()
            }
        }
    }

    // MARK: - Cached Selection State (Performance)

    /// Cached attributes for the current selection — updated only on selection changes
    /// or attribute mutations, NOT on geometry-only changes (move/resize/rotate).
    @Published public private(set) var cachedSelectionAttributes: ObjectAttributes = [:]

    /// Cached capabilities for the current selection
    @Published public private(set) var cachedSelectionCapabilities: SelectionCapabilities = .empty

    /// Recompute cached selection attributes and capabilities.
    /// Called when selection changes or when selected-object attributes are mutated
    /// (e.g. color, stroke width). NOT called on geometry-only mutations to avoid
    /// expensive recomputation during drag/resize.
    internal func refreshSelectionCache() {
        cachedSelectionAttributes = getSelectionAttributes()
        cachedSelectionCapabilities = SelectionCapabilities.from(objects: selectedObjects)
    }

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

    /// Tracks objects being edited for undo (object snapshot before editing started)
    private var editingObjectsSnapshot: [UUID: AnyCanvasObject] = [:]

    // MARK: - Computed Properties

    /// Check if any object is currently being edited (text or label)
    /// Note: LineObject.isEditing maps to isEditingLabel, so no special case needed
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
        let wrappedObject = AnyCanvasObject(obj)

        // Record undo action
        let action = AddObjectAction(object: wrappedObject, zIndex: obj.zIndex)
        undoManager?.recordWithoutExecuting(action)

        // Execute the addition
        objects.append(wrappedObject)
        sortObjectsByZIndex()
        refreshSelectionCache()
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
        refreshSelectionCache()
        return imageObj.id
    }

    // MARK: - Remove Objects

    /// Remove object by ID
    public func removeObject(withId id: UUID) {
        objects.removeAll { $0.id == id }
        refreshSelectionCache()
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
        refreshSelectionCache()
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
            // Stroke properties - use protocol for ANY strokable object
            if let strokable = first.asStrokable {
                result[ObjectAttributes.strokeColor] = strokable.strokeColor
                result[ObjectAttributes.strokeWidth] = strokable.strokeWidth
                result[ObjectAttributes.strokeStyle] = strokable.strokeStyle
            }

            // Fill properties - use protocol for ANY fillable object
            if let fillable = first.asFillable {
                result[ObjectAttributes.fillColor] = fillable.fillColor
                result[ObjectAttributes.fillOpacity] = fillable.fillOpacity
            }

            // Text properties - use protocol for ANY text content object
            // Note: LineObject now implements TextContentObject via computed properties
            if let textContent = first.asTextContent {
                result[ObjectAttributes.textColor] = textContent.textAttributes.textColor.color
                result[ObjectAttributes.fontSize] = textContent.textAttributes.fontSize
                result[ObjectAttributes.fontFamily] = textContent.textAttributes.fontFamily
                result[ObjectAttributes.horizontalTextAlignment] = textContent.textAttributes.horizontalAlignment
                result[ObjectAttributes.verticalTextAlignment] = textContent.textAttributes.verticalAlignment
            }
        }

        // Compare with remaining objects, remove mismatched attributes
        for obj in objects.dropFirst() {
            // Check stroke - use protocol for ANY strokable object
            if let strokable = obj.asStrokable {
                if result[ObjectAttributes.strokeColor] as? Color != strokable.strokeColor {
                    result.removeValue(forKey: ObjectAttributes.strokeColor)
                }
                if result[ObjectAttributes.strokeWidth] as? CGFloat != strokable.strokeWidth {
                    result.removeValue(forKey: ObjectAttributes.strokeWidth)
                }
                if result[ObjectAttributes.strokeStyle] as? StrokeStyleType != strokable.strokeStyle {
                    result.removeValue(forKey: ObjectAttributes.strokeStyle)
                }
            }

            // Check fill - use protocol for ANY fillable object
            if let fillable = obj.asFillable {
                if result[ObjectAttributes.fillColor] as? Color != fillable.fillColor {
                    result.removeValue(forKey: ObjectAttributes.fillColor)
                }
                if result[ObjectAttributes.fillOpacity] as? CGFloat != fillable.fillOpacity {
                    result.removeValue(forKey: ObjectAttributes.fillOpacity)
                }
            }

            // Check text - use protocol for ANY text content object
            // Note: LineObject now implements TextContentObject, so no special case needed
            if let textContent = obj.asTextContent {
                if result[ObjectAttributes.textColor] as? Color != textContent.textAttributes.textColor.color {
                    result.removeValue(forKey: ObjectAttributes.textColor)
                }
                if result[ObjectAttributes.fontSize] as? CGFloat != textContent.textAttributes.fontSize {
                    result.removeValue(forKey: ObjectAttributes.fontSize)
                }
                if result[ObjectAttributes.fontFamily] as? String != textContent.textAttributes.fontFamily {
                    result.removeValue(forKey: ObjectAttributes.fontFamily)
                }
                if result[ObjectAttributes.horizontalTextAlignment] as? HorizontalTextAlignment != textContent.textAttributes.horizontalAlignment {
                    result.removeValue(forKey: ObjectAttributes.horizontalTextAlignment)
                }
                if result[ObjectAttributes.verticalTextAlignment] as? VerticalTextAlignment != textContent.textAttributes.verticalAlignment {
                    result.removeValue(forKey: ObjectAttributes.verticalTextAlignment)
                }
            }
        }

        // Extract custom attributes if all selected objects support customization
        if !objects.isEmpty {
            // Try to get custom attributes from first object
            if let firstCustomizable = objects.first?.asCustomizable {
                var customAttrs = firstCustomizable.getCustomAttributes()

                // Compare with remaining objects
                for obj in objects.dropFirst() {
                    guard let customizable = obj.asCustomizable else {
                        // If any object doesn't support customization, clear all custom attrs
                        customAttrs.removeAll()
                        break
                    }

                    let objCustomAttrs = customizable.getCustomAttributes()

                    // Remove keys that don't match
                    for key in customAttrs.keys {
                        if !areEqual(customAttrs[key], objCustomAttrs[key]) {
                            customAttrs.removeValue(forKey: key)
                        }
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

        // Handle ArrowHead enum
        if let l = lhs as? ArrowHead, let r = rhs as? ArrowHead { return l == r }

        // Fallback for any Hashable types (handles Color, CodableColor, etc.)
        if let l = lhs as? any Hashable, let r = rhs as? any Hashable {
            return AnyHashable(l) == AnyHashable(r)
        }

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

        // Capture object state before editing for undo (with isEditing = false)
        var snapshot = objects[index]
        // Ensure the snapshot has isEditing = false so undo doesn't re-enter editing mode
        snapshot = snapshot.applying(["isEditing": false])
        editingObjectsSnapshot[objectId] = snapshot

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

    /// Apply a geometry mutation to the object at `index`.
    /// Uses AnyCanvasObject.applying() to avoid hard-coding object types.
    /// The closure receives a mutable reference to a thin `ObjectGeometry` value;
    /// changes are written back into `objects[index]`.
    private func applyGeometry(at index: Int, mutation: (inout ObjectGeometry) -> Void) {
        let obj = objects[index]
        var geo = ObjectGeometry(position: obj.position, size: obj.size, rotation: obj.rotation)
        mutation(&geo)

        // Use AnyCanvasObject.applying() to update geometry without type-specific dispatch
        objects[index] = obj.applying([
            "position": geo.position,
            "size": geo.size,
            "rotation": geo.rotation
        ])
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
    public func endAllEditing() {
        // Collect IDs of text objects that are empty and should be removed
        var idsToRemove: [UUID] = []
        var editedObjectIds: Set<UUID> = []

        for index in objects.indices where objects[index].isEditing {
            let objectId = objects[index].id

            // Check if this is a TextObject with empty text
            if let textObj = objects[index].asType(TextObject.self),
               textObj.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                idsToRemove.append(objectId)
            } else {
                mutateTextContent(at: index) { $0.isEditing = false }
                editedObjectIds.insert(objectId)
            }
        }

        // Record undo action for text changes
        // Skip recording if the before text was empty AND it's a TextObject (newly created text)
        // But DO record for LineObject labels even if empty (since the line already exists)
        if !editedObjectIds.isEmpty {
            var beforeObjects: [AnyCanvasObject] = []
            var afterObjects: [AnyCanvasObject] = []

            for objectId in editedObjectIds {
                if let beforeObj = editingObjectsSnapshot[objectId],
                   let afterObj = object(withId: objectId) {
                    if let beforeText = beforeObj.asTextContent,
                       let afterText = afterObj.asTextContent,
                       beforeText.text != afterText.text {

                        // Check if it's a standalone TextObject with initially empty text
                        let isNewTextObject = beforeObj.asType(TextObject.self) != nil && beforeText.text.isEmpty

                        // Record the action unless it's a new empty TextObject
                        if !isNewTextObject {
                            beforeObjects.append(beforeObj)
                            afterObjects.append(afterObj)
                        }
                    }
                }
            }

            if !beforeObjects.isEmpty {
                let action = UpdateAttributesAction(
                    objectIds: Set(beforeObjects.map { $0.id }),
                    beforeObjects: beforeObjects,
                    afterObjects: afterObjects
                )
                undoManager?.recordWithoutExecuting(action)
            }
        }

        // Clear editing snapshot
        editingObjectsSnapshot.removeAll()

        // Remove empty text objects
        for id in idsToRemove {
            objects.removeAll { $0.id == id }
        }
    }

    /// Apply a mutation to any TextContentObject at the given index.
    /// Works with ANY object implementing TextContentObject protocol.
    private func mutateTextContent(at index: Int, mutation: (inout TextContentProxy) -> Void) {
        guard let textContent = objects[index].asTextContent else { return }
        var proxy = TextContentProxy(text: textContent.text, isEditing: textContent.isEditing)
        mutation(&proxy)

        objects[index] = objects[index].applying([
            "text": proxy.text,
            "isEditing": proxy.isEditing
        ])
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

        // Capture objects being deleted for undo
        let deletedObjects = objects.filter { idsToRemove.contains($0.id) }
        let previousSelection = selectionState.selectedIds

        // Record undo action
        let action = DeleteObjectsAction(deletedObjects: deletedObjects, previousSelection: previousSelection)
        undoManager?.recordWithoutExecuting(action)

        // Execute the deletion
        objects.removeAll { idsToRemove.contains($0.id) }
        selectionState.clear()
        // selectionState.clear() triggers didSet → refreshSelectionCache()
    }

    // MARK: - Z-Order Management

    /// Sort objects array by zIndex
    internal func sortObjectsByZIndex() {
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

    // MARK: - Alignment & Distribution

    /// Align selected objects according to the given action.
    /// Locked objects are included in the reference-edge calculation but are not moved.
    /// Requires at least 2 selected objects; returns early otherwise.
    public func alignSelected(_ action: AlignmentAction) {
        let selected = selectedObjects
        guard selected.count >= 2 else { return }

        // Compute reference edges / centers across ALL selected objects (including locked)
        let boxes = selected.map { $0.boundingBox() }
        let minX = boxes.map { $0.minX }.min()!
        let maxX = boxes.map { $0.maxX }.max()!
        let minY = boxes.map { $0.minY }.min()!
        let maxY = boxes.map { $0.maxY }.max()!
        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2

        for obj in selected {
            guard !obj.isLocked else { continue }
            guard let index = objectIndex(withId: obj.id) else { continue }
            let box = obj.boundingBox()

            let dx: CGFloat
            let dy: CGFloat

            switch action {
            case .left:
                dx = minX - box.minX
                dy = 0
            case .right:
                dx = maxX - box.maxX
                dy = 0
            case .top:
                dx = 0
                dy = minY - box.minY
            case .bottom:
                dx = 0
                dy = maxY - box.maxY
            case .centerHorizontal:
                dx = centerX - box.midX
                dy = 0
            case .centerVertical:
                dx = 0
                dy = centerY - box.midY
            }

            applyGeometry(at: index) {
                $0.position.x += dx
                $0.position.y += dy
            }
        }
    }

    /// Distribute selected objects with equal gaps between edges along the chosen axis.
    /// The first and last objects (by position) stay in place and define the span.
    /// Objects in between are repositioned with equal spacing between their edges.
    /// Locked objects are not moved but are included in the total object width/height calculation.
    /// Requires at least 3 selected objects; returns early otherwise.
    public func distributeSelected(_ action: DistributionAction) {
        let selected = selectedObjects
        guard selected.count >= 3 else { return }

        switch action {
        case .horizontal:
            // Sort by left edge position
            let sorted = selected.sorted { $0.boundingBox().minX < $1.boundingBox().minX }
            let firstBox = sorted.first!.boundingBox()
            let lastBox = sorted.last!.boundingBox()

            // Calculate total span and total width of all objects
            let totalSpan = lastBox.minX - firstBox.maxX  // Space available between first and last
            let totalObjectWidth = sorted.dropFirst().dropLast().reduce(CGFloat(0)) { $0 + $1.boundingBox().width }

            // Equal gap between objects
            let gap = (totalSpan - totalObjectWidth) / CGFloat(sorted.count - 1)

            // Position objects from left to right
            var currentX = firstBox.maxX + gap
            for obj in sorted.dropFirst().dropLast() {
                guard !obj.isLocked else {
                    currentX += obj.boundingBox().width + gap
                    continue
                }
                guard let index = objectIndex(withId: obj.id) else { continue }
                let box = obj.boundingBox()
                let dx = currentX - box.minX
                applyGeometry(at: index) { $0.position.x += dx }
                currentX += box.width + gap
            }

        case .vertical:
            // Sort by top edge position
            let sorted = selected.sorted { $0.boundingBox().minY < $1.boundingBox().minY }
            let firstBox = sorted.first!.boundingBox()
            let lastBox = sorted.last!.boundingBox()

            // Calculate total span and total height of all objects
            let totalSpan = lastBox.minY - firstBox.maxY  // Space available between first and last
            let totalObjectHeight = sorted.dropFirst().dropLast().reduce(CGFloat(0)) { $0 + $1.boundingBox().height }

            // Equal gap between objects
            let gap = (totalSpan - totalObjectHeight) / CGFloat(sorted.count - 1)

            // Position objects from top to bottom
            var currentY = firstBox.maxY + gap
            for obj in sorted.dropFirst().dropLast() {
                guard !obj.isLocked else {
                    currentY += obj.boundingBox().height + gap
                    continue
                }
                guard let index = objectIndex(withId: obj.id) else { continue }
                let box = obj.boundingBox()
                let dy = currentY - box.minY
                applyGeometry(at: index) { $0.position.y += dy }
                currentY += box.height + gap
            }
        }
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
        renderObjectsToImage(objects: objects, scale: scale, padding: padding)
    }

    /// Render only selected objects to an NSImage.
    /// The image covers the bounding box of selected objects, with optional padding.
    /// Returns nil if there are no selected objects.
    @MainActor
    public func renderSelectionToImage(scale: CGFloat = 2.0, padding: CGFloat = 40) -> NSImage? {
        let selectedObjects = objects.filter { selectedIds.contains($0.id) }
        return renderObjectsToImage(objects: selectedObjects, scale: scale, padding: padding)
    }

    /// Internal helper: renders a specific set of objects to an NSImage.
    /// Returns nil if the objects array is empty.
    @MainActor
    private func renderObjectsToImage(objects: [AnyCanvasObject], scale: CGFloat, padding: CGFloat) -> NSImage? {
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

    // MARK: - Internal Helpers for Undo/Redo

    /// Add an object directly without incrementing nextZIndex (for undo/redo)
    internal func _addObjectDirectly(_ object: AnyCanvasObject) {
        objects.append(object)
        sortObjectsByZIndex()
        refreshSelectionCache()
    }

    /// Remove objects by IDs (for undo/redo)
    internal func _removeObjects(ids: Set<UUID>) {
        objects.removeAll { ids.contains($0.id) }
        sortObjectsByZIndex()
        refreshSelectionCache()
    }

    /// Update object at index (for undo/redo)
    internal func _updateObjectAtIndex(_ index: Int, with object: AnyCanvasObject) {
        guard index < objects.count else { return }
        objects[index] = object
    }

    /// Set objects array directly (for undo/redo batch operations)
    internal func _setObjects(_ newObjects: [AnyCanvasObject]) {
        objects = newObjects
        sortObjectsByZIndex()
        refreshSelectionCache()
    }

    /// Set selection state directly (for undo/redo)
    internal func _setSelection(_ ids: Set<UUID>) {
        selectionState.selectMultiple(ids)
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
