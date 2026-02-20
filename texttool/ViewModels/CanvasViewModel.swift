//
//  CanvasViewModel.swift
//  texttool
//
//  Created by Flex on 12/11/25.
//

import SwiftUI
import Combine

@MainActor
class CanvasViewModel: ObservableObject {
    // MARK: - Unified Object Storage

    /// Primary storage for all canvas objects, sorted by zIndex
    @Published private(set) var objects: [AnyCanvasObject] = []

    /// Next available zIndex for new objects
    private var nextZIndex: Int = 0

    // MARK: - Tool State

    @Published var selectedTool: DrawingTool = .select {
        didSet {
            // Exit text editing when switching tools
            deselectAll()
        }
    }

    /// Multi-selection state
    @Published var selectionState = SelectionState()

    /// Backward compatibility: returns the single selected ID if exactly one object is selected
    var selectedObjectId: UUID? {
        get { selectionState.singleSelectedId }
        set {
            if let id = newValue {
                selectionState.select(id)
            } else {
                selectionState.clear()
            }
        }
    }
    @Published var activeTextSize: CGFloat = 16
    @Published var activeColor: Color = .black
    @Published var autoResizeShapes: Bool = true

    // MARK: - Viewport State

    @Published var viewport = ViewportState()

    // MARK: - Transient Drag State

    @Published var dragStartPoint: CGPoint?
    @Published var currentDragPoint: CGPoint?

    // MARK: - Computed Properties

    /// Returns all text objects
    var textObjects: [TextObject] {
        objects.compactMap { $0.asTextObject }
    }

    /// Returns all shape objects
    var shapeObjects: [ShapeObject] {
        objects.compactMap { $0.asShapeObject }
    }

    /// Check if any object is currently being edited
    var isAnyObjectEditing: Bool {
        objects.contains { $0.isEditing }
    }

    /// Get the currently editing object's ID and contains closure, if any
    func editingObject() -> (id: UUID, contains: (CGPoint) -> Bool)? {
        guard let wrapper = objects.first(where: { $0.isEditing }) else { return nil }
        return (wrapper.id, { wrapper.contains($0) })
    }

    // MARK: - Object Retrieval

    /// Find object by ID
    func object(withId id: UUID) -> AnyCanvasObject? {
        objects.first { $0.id == id }
    }

    /// Find object index by ID
    private func objectIndex(withId id: UUID) -> Int? {
        objects.firstIndex { $0.id == id }
    }

    // MARK: - Add Objects

    func addTextObject(at position: CGPoint) -> UUID {
        var textObj = TextObject(
            position: position,
            text: "",
            fontSize: activeTextSize,
            color: activeColor,
            isEditing: true
        )
        textObj.zIndex = nextZIndex
        nextZIndex += 1

        objects.append(AnyCanvasObject(textObj))
        sortObjectsByZIndex()
        return textObj.id
    }

    func addShape(preset: ShapePreset, from start: CGPoint, to end: CGPoint) {
        let origin = CGPoint(
            x: min(start.x, end.x),
            y: min(start.y, end.y)
        )
        let size = CGSize(
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )

        // Skip tiny shapes (likely accidental clicks)
        guard size.width > 1 && size.height > 1 else { return }

        var shape = ShapeObject(
            position: origin,
            size: size,
            preset: preset,
            color: activeColor,
            autoResizeHeight: autoResizeShapes
        )
        shape.zIndex = nextZIndex
        nextZIndex += 1

        objects.append(AnyCanvasObject(shape))
        sortObjectsByZIndex()
    }

    // MARK: - Remove Objects

    /// Remove object by ID
    func removeObject(withId id: UUID) {
        objects.removeAll { $0.id == id }
    }

    // MARK: - Update Objects

    /// Generic update: extracts an object of type T, applies mutation, and stores it back
    private func updateObject<T: CanvasObject>(
        withId id: UUID,
        as _: T.Type,
        update: (inout T) -> Void
    ) {
        guard let index = objectIndex(withId: id),
              var obj = objects[index].asType(T.self) else { return }
        update(&obj)
        objects[index] = AnyCanvasObject(obj)
    }

    /// Update a TextObject in place
    func updateTextObject(withId id: UUID, update: (inout TextObject) -> Void) {
        updateObject(withId: id, as: TextObject.self, update: update)
    }

    /// Update a ShapeObject in place
    func updateShapeObject(withId id: UUID, update: (inout ShapeObject) -> Void) {
        updateObject(withId: id, as: ShapeObject.self, update: update)
    }

    // MARK: - Hit Testing & Selection

    func selectObject(at point: CGPoint) -> UUID? {
        // Check objects in reverse z-order (highest zIndex first)
        for obj in objects.reversed() {
            if obj.contains(point) {
                return obj.id
            }
        }
        return nil
    }

    func startEditing(objectId: UUID) {
        guard let index = objectIndex(withId: objectId) else { return }
        guard objects[index].hasTextContent else { return }
        objects[index].isEditing = true
        objects[index] = objects[index].rebuilt()
        selectedObjectId = objectId
    }

    func updateText(objectId: UUID, text: String) {
        guard let index = objectIndex(withId: objectId) else { return }
        guard objects[index].hasTextContent else { return }
        objects[index].text = text
        objects[index] = objects[index].rebuilt()
    }

    func updateTextObjectSize(objectId: UUID, size: CGSize) {
        updateTextObject(withId: objectId) { $0.size = size }
    }

    func deselectAll() {
        selectionState.clear()
        endAllEditing()
    }

    // MARK: - Move Objects

    func moveObject(id: UUID, by offset: CGSize) {
        guard let index = objectIndex(withId: id) else { return }
        objects[index].position.x += offset.width
        objects[index].position.y += offset.height
        objects[index] = objects[index].rebuilt()
    }

    /// Update rotation for an object
    func updateObjectRotation(id: UUID, rotation: CGFloat) {
        guard let index = objectIndex(withId: id) else { return }
        objects[index].rotation = rotation
        objects[index] = objects[index].rebuilt()
    }

    /// Update position and rotation for an object (used by group rotation)
    func updateObjectPositionAndRotation(id: UUID, position: CGPoint, rotation: CGFloat) {
        guard let index = objectIndex(withId: id) else { return }
        objects[index].position = position
        objects[index].rotation = rotation
        objects[index] = objects[index].rebuilt()
    }

    /// Update position and size for an object (used by resize)
    func updateObjectFrame(id: UUID, position: CGPoint, size: CGSize) {
        guard let index = objectIndex(withId: id) else { return }
        objects[index].position = position
        objects[index].size = size
        objects[index] = objects[index].rebuilt()
    }

    func selectObjectOnly(id: UUID) {
        selectionState.select(id)
        endAllEditing()
    }

    /// Toggle selection of an object (for shift+click)
    func toggleObjectSelection(id: UUID) {
        // End any text editing first
        endAllEditing()
        selectionState.toggleSelection(id)
    }

    /// Select multiple objects (for marquee selection)
    func selectMultiple(ids: Set<UUID>) {
        endAllEditing()
        selectionState.selectMultiple(ids)
    }

    /// Add multiple objects to selection (for shift+marquee)
    func addMultipleToSelection(ids: Set<UUID>) {
        endAllEditing()
        selectionState.addMultipleToSelection(ids)
    }

    /// Check if an object is currently selected
    func isSelected(_ id: UUID) -> Bool {
        selectionState.isSelected(id)
    }

    /// Get all selected object IDs
    var selectedIds: Set<UUID> {
        selectionState.selectedIds
    }

    /// Get the selection box for currently selected objects
    var selectionBox: SelectionBox? {
        guard selectionState.hasSelection else { return nil }

        let selectedObjects = objects.filter { selectionState.isSelected($0.id) }
        return SelectionBox.from(objects: selectedObjects)
    }

    /// Get selected objects as an array
    var selectedObjects: [AnyCanvasObject] {
        objects.filter { selectionState.isSelected($0.id) }
    }

    /// End all text editing without clearing selection
    private func endAllEditing() {
        for index in objects.indices where objects[index].isEditing {
            objects[index].isEditing = false
            objects[index] = objects[index].rebuilt()
        }
    }

    /// Find all objects within a marquee rectangle
    func objectsInRect(_ rect: CGRect) -> Set<UUID> {
        var ids = Set<UUID>()
        for obj in objects {
            let bbox = obj.boundingBox()
            if rect.intersects(bbox) {
                ids.insert(obj.id)
            }
        }
        return ids
    }

    /// Move all selected objects by offset
    func moveSelectedObjects(by offset: CGSize) {
        for id in selectionState.selectedIds {
            moveObject(id: id, by: offset)
        }
    }

    // MARK: - Z-Order Management

    /// Sort objects array by zIndex
    private func sortObjectsByZIndex() {
        objects.sort { $0.zIndex < $1.zIndex }
    }

    // MARK: - Viewport Control

    /// Pan the viewport by a delta
    func panViewport(by delta: CGSize) {
        viewport.pan(by: delta)
    }

    /// Zoom the viewport by a factor around a point
    func zoomViewport(by factor: CGFloat, around anchor: CGPoint) {
        viewport.zoom(by: factor, around: anchor)
    }

    /// Reset viewport to default
    func resetViewport() {
        viewport.reset()
    }
}
