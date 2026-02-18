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
    @Published var textObjects: [TextObject] = []
    @Published var rectangleObjects: [RectangleObject] = []
    @Published var circleObjects: [CircleObject] = []
    @Published var selectedTool: DrawingTool = .select {
        didSet {
            // Exit text editing when switching tools
            deselectAll()
        }
    }
    @Published var selectedObjectId: UUID?
    @Published var activeTextSize: CGFloat = 16
    @Published var activeColor: Color = .black
    @Published var autoResizeShapes: Bool = true

    // Transient state for shape dragging
    @Published var dragStartPoint: CGPoint?
    @Published var currentDragPoint: CGPoint?

    func addTextObject(at position: CGPoint) -> UUID {
        let textObj = TextObject(
            position: position,
            text: "",
            fontSize: activeTextSize,
            color: activeColor,
            isEditing: true
        )
        textObjects.append(textObj)
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

        let rectObj = RectangleObject(
            position: origin,
            size: size,
            color: activeColor,
            autoResizeHeight: autoResizeShapes
        )
        rectangleObjects.append(rectObj)
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

        let circleObj = CircleObject(
            position: origin,
            size: size,
            color: activeColor,
            autoResizeHeight: autoResizeShapes
        )
        circleObjects.append(circleObj)
    }

    func selectObject(at point: CGPoint) -> UUID? {
        // Check text objects (in reverse for z-order)
        for textObj in textObjects.reversed() {
            if textObj.contains(point) {
                return textObj.id
            }
        }

        // Check circle objects (in reverse for z-order)
        for circleObj in circleObjects.reversed() {
            if circleObj.contains(point) {
                return circleObj.id
            }
        }

        // Check rectangle objects (in reverse for z-order)
        for rectObj in rectangleObjects.reversed() {
            if rectObj.contains(point) {
                return rectObj.id
            }
        }

        return nil
    }

    func startEditing(objectId: UUID) {
        // First check if it's a text object
        if let index = textObjects.firstIndex(where: { $0.id == objectId }) {
            textObjects[index].isEditing = true
            selectedObjectId = objectId
        }
        // Then check if it's a rectangle object
        else if let index = rectangleObjects.firstIndex(where: { $0.id == objectId }) {
            rectangleObjects[index].isEditing = true
            selectedObjectId = objectId
        }
        // Then check if it's a circle object
        else if let index = circleObjects.firstIndex(where: { $0.id == objectId }) {
            circleObjects[index].isEditing = true
            selectedObjectId = objectId
        }
    }

    func updateText(objectId: UUID, text: String) {
        // Update text object
        if let index = textObjects.firstIndex(where: { $0.id == objectId }) {
            textObjects[index].text = text
        }
        // Or update rectangle object text
        else if let index = rectangleObjects.firstIndex(where: { $0.id == objectId }) {
            rectangleObjects[index].text = text
        }
        // Or update circle object text
        else if let index = circleObjects.firstIndex(where: { $0.id == objectId }) {
            circleObjects[index].text = text
        }
    }

    func updateTextObjectSize(objectId: UUID, size: CGSize) {
        if let index = textObjects.firstIndex(where: { $0.id == objectId }) {
            textObjects[index].size = size
        }
    }

    func deselectAll() {
        selectedObjectId = nil
        // End any active text editing
        for index in textObjects.indices {
            textObjects[index].isEditing = false
        }
        // End any active rectangle text editing
        for index in rectangleObjects.indices {
            rectangleObjects[index].isEditing = false
        }
        // End any active circle text editing
        for index in circleObjects.indices {
            circleObjects[index].isEditing = false
        }
    }

    func moveTextObject(id: UUID, by offset: CGSize) {
        if let index = textObjects.firstIndex(where: { $0.id == id }) {
            textObjects[index].position.x += offset.width
            textObjects[index].position.y += offset.height
        }
    }

    func moveRectangleObject(id: UUID, by offset: CGSize) {
        if let index = rectangleObjects.firstIndex(where: { $0.id == id }) {
            rectangleObjects[index].position.x += offset.width
            rectangleObjects[index].position.y += offset.height
        }
    }

    func moveCircleObject(id: UUID, by offset: CGSize) {
        if let index = circleObjects.firstIndex(where: { $0.id == id }) {
            circleObjects[index].position.x += offset.width
            circleObjects[index].position.y += offset.height
        }
    }

    func selectObjectOnly(id: UUID) {
        selectedObjectId = id
        // Deselect any text editing
        for index in textObjects.indices {
            textObjects[index].isEditing = false
        }
        // Deselect any rectangle text editing
        for index in rectangleObjects.indices {
            rectangleObjects[index].isEditing = false
        }
        // Deselect any circle text editing
        for index in circleObjects.indices {
            circleObjects[index].isEditing = false
        }
    }
}
