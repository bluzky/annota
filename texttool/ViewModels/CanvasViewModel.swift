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

    // MARK: - Transient Drag State

    @Published var dragStartPoint: CGPoint?
    @Published var currentDragPoint: CGPoint?

    // MARK: - Backward Compatibility Computed Properties

    /// Returns all text objects (for view compatibility)
    var textObjects: [TextObject] {
        objects.compactMap { $0.asTextObject }
    }

    /// Returns all rectangle objects (for view compatibility)
    var rectangleObjects: [RectangleObject] {
        objects.compactMap { $0.asRectangleObject }
    }

    /// Returns all circle objects (for view compatibility)
    var circleObjects: [CircleObject] {
        objects.compactMap { $0.asCircleObject }
    }

    /// Check if any object is currently being edited
    var isAnyObjectEditing: Bool {
        for wrapper in objects {
            if let textObj = wrapper.asTextObject, textObj.isEditing {
                return true
            } else if let rectObj = wrapper.asRectangleObject, rectObj.isEditing {
                return true
            } else if let circleObj = wrapper.asCircleObject, circleObj.isEditing {
                return true
            }
        }
        return false
    }

    /// Get the currently editing object's ID and bounds, if any
    func editingObject() -> (id: UUID, contains: (CGPoint) -> Bool)? {
        for wrapper in objects {
            if let textObj = wrapper.asTextObject, textObj.isEditing {
                return (textObj.id, { textObj.contains($0) })
            } else if let rectObj = wrapper.asRectangleObject, rectObj.isEditing {
                return (rectObj.id, { rectObj.contains($0) })
            } else if let circleObj = wrapper.asCircleObject, circleObj.isEditing {
                return (circleObj.id, { circleObj.contains($0) })
            }
        }
        return nil
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

    func addRectangle(from start: CGPoint, to end: CGPoint) {
        let origin = CGPoint(
            x: min(start.x, end.x),
            y: min(start.y, end.y)
        )
        let size = CGSize(
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )

        // Skip tiny rectangles (likely accidental clicks)
        guard size.width > 1 && size.height > 1 else { return }

        var rectObj = RectangleObject(
            position: origin,
            size: size,
            color: activeColor,
            autoResizeHeight: autoResizeShapes
        )
        rectObj.zIndex = nextZIndex
        nextZIndex += 1

        objects.append(AnyCanvasObject(rectObj))
        sortObjectsByZIndex()
    }

    func addCircle(from start: CGPoint, to end: CGPoint) {
        let origin = CGPoint(
            x: min(start.x, end.x),
            y: min(start.y, end.y)
        )
        let size = CGSize(
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )

        // Skip tiny circles (likely accidental clicks)
        guard size.width > 1 && size.height > 1 else { return }

        var circleObj = CircleObject(
            position: origin,
            size: size,
            color: activeColor,
            autoResizeHeight: autoResizeShapes
        )
        circleObj.zIndex = nextZIndex
        nextZIndex += 1

        objects.append(AnyCanvasObject(circleObj))
        sortObjectsByZIndex()
    }

    /// Add any canvas object (generic method for future object types)
    func addObject<T: CanvasObject>(_ object: T) {
        var mutableObject = object
        mutableObject.zIndex = nextZIndex
        nextZIndex += 1

        objects.append(AnyCanvasObject(mutableObject))
        sortObjectsByZIndex()
    }

    // MARK: - Remove Objects

    /// Remove object by ID
    func removeObject(withId id: UUID) {
        objects.removeAll { $0.id == id }
    }

    /// Remove multiple objects by IDs
    func removeObjects(withIds ids: Set<UUID>) {
        objects.removeAll { ids.contains($0.id) }
    }

    // MARK: - Update Objects

    /// Update a TextObject in place
    func updateTextObject(withId id: UUID, update: (inout TextObject) -> Void) {
        guard let index = objectIndex(withId: id),
              var textObj = objects[index].asTextObject else { return }
        update(&textObj)
        objects[index] = AnyCanvasObject(textObj)
    }

    /// Update a RectangleObject in place
    func updateRectangleObject(withId id: UUID, update: (inout RectangleObject) -> Void) {
        guard let index = objectIndex(withId: id),
              var rectObj = objects[index].asRectangleObject else { return }
        update(&rectObj)
        objects[index] = AnyCanvasObject(rectObj)
    }

    /// Update a CircleObject in place
    func updateCircleObject(withId id: UUID, update: (inout CircleObject) -> Void) {
        guard let index = objectIndex(withId: id),
              var circleObj = objects[index].asCircleObject else { return }
        update(&circleObj)
        objects[index] = AnyCanvasObject(circleObj)
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

    /// Advanced hit test returning detailed information
    func hitTest(at point: CGPoint, threshold: CGFloat = 8) -> (UUID, HitTestResult)? {
        for obj in objects.reversed() {
            if let result = obj.hitTest(point, threshold: threshold) {
                return (obj.id, result)
            }
        }
        return nil
    }

    func startEditing(objectId: UUID) {
        guard let index = objectIndex(withId: objectId) else { return }

        let wrapper = objects[index]

        // Handle based on object type
        if var textObj = wrapper.asTextObject {
            textObj.isEditing = true
            objects[index] = AnyCanvasObject(textObj)
            selectedObjectId = objectId
        } else if var rectObj = wrapper.asRectangleObject {
            rectObj.isEditing = true
            objects[index] = AnyCanvasObject(rectObj)
            selectedObjectId = objectId
        } else if var circleObj = wrapper.asCircleObject {
            circleObj.isEditing = true
            objects[index] = AnyCanvasObject(circleObj)
            selectedObjectId = objectId
        }
    }

    func updateText(objectId: UUID, text: String) {
        guard let index = objectIndex(withId: objectId) else { return }

        let wrapper = objects[index]

        if var textObj = wrapper.asTextObject {
            textObj.text = text
            objects[index] = AnyCanvasObject(textObj)
        } else if var rectObj = wrapper.asRectangleObject {
            rectObj.text = text
            objects[index] = AnyCanvasObject(rectObj)
        } else if var circleObj = wrapper.asCircleObject {
            circleObj.text = text
            objects[index] = AnyCanvasObject(circleObj)
        }
    }

    func updateTextObjectSize(objectId: UUID, size: CGSize) {
        updateTextObject(withId: objectId) { $0.size = size }
    }

    func deselectAll() {
        selectionState.clear()

        // End any active text editing
        for (index, wrapper) in objects.enumerated() {
            if var textObj = wrapper.asTextObject, textObj.isEditing {
                textObj.isEditing = false
                objects[index] = AnyCanvasObject(textObj)
            } else if var rectObj = wrapper.asRectangleObject, rectObj.isEditing {
                rectObj.isEditing = false
                objects[index] = AnyCanvasObject(rectObj)
            } else if var circleObj = wrapper.asCircleObject, circleObj.isEditing {
                circleObj.isEditing = false
                objects[index] = AnyCanvasObject(circleObj)
            }
        }
    }

    // MARK: - Move Objects

    func moveObject(id: UUID, by offset: CGSize) {
        guard let index = objectIndex(withId: id) else { return }

        let wrapper = objects[index]

        if var textObj = wrapper.asTextObject {
            textObj.position.x += offset.width
            textObj.position.y += offset.height
            objects[index] = AnyCanvasObject(textObj)
        } else if var rectObj = wrapper.asRectangleObject {
            rectObj.position.x += offset.width
            rectObj.position.y += offset.height
            objects[index] = AnyCanvasObject(rectObj)
        } else if var circleObj = wrapper.asCircleObject {
            circleObj.position.x += offset.width
            circleObj.position.y += offset.height
            objects[index] = AnyCanvasObject(circleObj)
        }
    }

    // Backward compatibility methods
    func moveTextObject(id: UUID, by offset: CGSize) {
        moveObject(id: id, by: offset)
    }

    func moveRectangleObject(id: UUID, by offset: CGSize) {
        moveObject(id: id, by: offset)
    }

    func moveCircleObject(id: UUID, by offset: CGSize) {
        moveObject(id: id, by: offset)
    }

    func selectObjectOnly(id: UUID) {
        selectionState.select(id)

        // Deselect any text editing
        for (index, wrapper) in objects.enumerated() {
            if var textObj = wrapper.asTextObject, textObj.isEditing {
                textObj.isEditing = false
                objects[index] = AnyCanvasObject(textObj)
            } else if var rectObj = wrapper.asRectangleObject, rectObj.isEditing {
                rectObj.isEditing = false
                objects[index] = AnyCanvasObject(rectObj)
            } else if var circleObj = wrapper.asCircleObject, circleObj.isEditing {
                circleObj.isEditing = false
                objects[index] = AnyCanvasObject(circleObj)
            }
        }
    }

    /// Toggle selection of an object (for shift+click)
    func toggleObjectSelection(id: UUID) {
        // End any text editing first
        endAllEditing()
        selectionState.toggleSelection(id)
    }

    /// Add object to current selection (for shift+click on unselected)
    func addToSelection(id: UUID) {
        endAllEditing()
        selectionState.addToSelection(id)
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

    /// End all text editing without clearing selection
    private func endAllEditing() {
        for (index, wrapper) in objects.enumerated() {
            if var textObj = wrapper.asTextObject, textObj.isEditing {
                textObj.isEditing = false
                objects[index] = AnyCanvasObject(textObj)
            } else if var rectObj = wrapper.asRectangleObject, rectObj.isEditing {
                rectObj.isEditing = false
                objects[index] = AnyCanvasObject(rectObj)
            } else if var circleObj = wrapper.asCircleObject, circleObj.isEditing {
                circleObj.isEditing = false
                objects[index] = AnyCanvasObject(circleObj)
            }
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

    /// Bring object to front (highest zIndex)
    func bringToFront(id: UUID) {
        guard let index = objectIndex(withId: id) else { return }

        let wrapper = objects[index]

        if var textObj = wrapper.asTextObject {
            textObj.zIndex = nextZIndex
            nextZIndex += 1
            objects[index] = AnyCanvasObject(textObj)
        } else if var rectObj = wrapper.asRectangleObject {
            rectObj.zIndex = nextZIndex
            nextZIndex += 1
            objects[index] = AnyCanvasObject(rectObj)
        } else if var circleObj = wrapper.asCircleObject {
            circleObj.zIndex = nextZIndex
            nextZIndex += 1
            objects[index] = AnyCanvasObject(circleObj)
        }

        sortObjectsByZIndex()
    }

    /// Send object to back (lowest zIndex)
    func sendToBack(id: UUID) {
        guard let index = objectIndex(withId: id) else { return }

        // Find minimum zIndex
        let minZIndex = objects.map { $0.zIndex }.min() ?? 0

        let wrapper = objects[index]

        if var textObj = wrapper.asTextObject {
            textObj.zIndex = minZIndex - 1
            objects[index] = AnyCanvasObject(textObj)
        } else if var rectObj = wrapper.asRectangleObject {
            rectObj.zIndex = minZIndex - 1
            objects[index] = AnyCanvasObject(rectObj)
        } else if var circleObj = wrapper.asCircleObject {
            circleObj.zIndex = minZIndex - 1
            objects[index] = AnyCanvasObject(circleObj)
        }

        sortObjectsByZIndex()
    }
}
