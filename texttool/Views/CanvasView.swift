//
//  CanvasView.swift
//  texttool
//
//  Created by Flex on 12/11/25.
//

import SwiftUI

struct CanvasView: View {
    @ObservedObject var viewModel: CanvasViewModel
    @State private var draggedObjectId: UUID?
    @State private var lastDragLocation: CGPoint?
    @State private var lastTapTime: Date?
    @State private var lastTapLocation: CGPoint?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background - gray canvas
                Color(red: 0xd8/255, green: 0xd8/255, blue: 0xd8/255)

                // Dot grid pattern
                Canvas { context, size in
                    let dotSpacing: CGFloat = 20
                    let dotRadius: CGFloat = 1
                    let dotColor = Color(red: 0xc0/255, green: 0xc0/255, blue: 0xc0/255)

                    for x in stride(from: 0, through: size.width, by: dotSpacing) {
                        for y in stride(from: 0, through: size.height, by: dotSpacing) {
                            let rect = CGRect(x: x - dotRadius, y: y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
                            context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                        }
                    }
                }

                // Render rectangle objects
                ForEach(viewModel.rectangleObjects) { rectObj in
                    RectangleObjectView(
                        object: rectObj,
                        isSelected: viewModel.selectedObjectId == rectObj.id,
                        viewModel: viewModel
                    )
                }

                // Render circle objects
                ForEach(viewModel.circleObjects) { circleObj in
                    CircleObjectView(
                        object: circleObj,
                        isSelected: viewModel.selectedObjectId == circleObj.id,
                        viewModel: viewModel
                    )
                }

                // Render text objects
                ForEach(viewModel.textObjects) { textObj in
                    TextObjectView(
                        object: textObj,
                        viewModel: viewModel,
                        isSelected: viewModel.selectedObjectId == textObj.id
                    )
                }

                // Rectangle drag preview
                if viewModel.selectedTool == .rectangle,
                   let start = viewModel.dragStartPoint,
                   let current = viewModel.currentDragPoint {
                    let width = abs(current.x - start.x)
                    let height = abs(current.y - start.y)
                    let x = min(start.x, current.x) + width / 2
                    let y = min(start.y, current.y) + height / 2

                    Rectangle()
                        .stroke(viewModel.activeColor.opacity(0.5), lineWidth: 2)
                        .frame(width: width, height: height)
                        .position(x: x, y: y)
                }

                // Circle drag preview
                if viewModel.selectedTool == .circle,
                   let start = viewModel.dragStartPoint,
                   let current = viewModel.currentDragPoint {
                    let width = abs(current.x - start.x)
                    let height = abs(current.y - start.y)
                    let x = min(start.x, current.x) + width / 2
                    let y = min(start.y, current.y) + height / 2

                    Circle()
                        .stroke(viewModel.activeColor.opacity(0.5), lineWidth: 2)
                        .frame(width: width, height: height)
                        .position(x: x, y: y)
                }
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    handleDragChanged(value)
                }
                .onEnded { value in
                    handleDragEnded(value)
                }
        )
    }

    private func handleDragChanged(_ value: DragGesture.Value) {
        if viewModel.selectedTool == .rectangle || viewModel.selectedTool == .circle {
            if viewModel.dragStartPoint == nil {
                viewModel.dragStartPoint = value.startLocation
            }
            viewModel.currentDragPoint = value.location
        } else if viewModel.selectedTool == .select {
            // Handle dragging selected object
            if draggedObjectId == nil {
                // Check if we started drag on a selected object
                if let objectId = viewModel.selectObject(at: value.startLocation) {
                    draggedObjectId = objectId
                    lastDragLocation = value.startLocation
                }
            }

            if let objectId = draggedObjectId, let lastLocation = lastDragLocation {
                let offset = CGSize(
                    width: value.location.x - lastLocation.x,
                    height: value.location.y - lastLocation.y
                )

                // Check if object is text, rectangle, or circle and move it
                if viewModel.textObjects.contains(where: { $0.id == objectId }) {
                    viewModel.moveTextObject(id: objectId, by: offset)
                } else if viewModel.rectangleObjects.contains(where: { $0.id == objectId }) {
                    viewModel.moveRectangleObject(id: objectId, by: offset)
                } else if viewModel.circleObjects.contains(where: { $0.id == objectId }) {
                    viewModel.moveCircleObject(id: objectId, by: offset)
                }

                lastDragLocation = value.location
            }
        }
    }

    private func handleDragEnded(_ value: DragGesture.Value) {
        let distance = hypot(
            value.location.x - value.startLocation.x,
            value.location.y - value.startLocation.y
        )

        // If it's a click (minimal drag)
        if distance < 5 {
            handleClick(at: value.location)
        } else if viewModel.selectedTool == .rectangle {
            // It's a drag for rectangle
            viewModel.addRectangle(
                from: viewModel.dragStartPoint ?? value.startLocation,
                to: value.location
            )
        } else if viewModel.selectedTool == .circle {
            // It's a drag for circle
            viewModel.addCircle(
                from: viewModel.dragStartPoint ?? value.startLocation,
                to: value.location
            )
        }

        // Reset drag state
        viewModel.dragStartPoint = nil
        viewModel.currentDragPoint = nil
        draggedObjectId = nil
        lastDragLocation = nil
    }

    private func handleClick(at location: CGPoint) {
        // Check if any object is currently being edited
        let isEditing = viewModel.textObjects.contains { $0.isEditing } ||
                        viewModel.rectangleObjects.contains { $0.isEditing } ||
                        viewModel.circleObjects.contains { $0.isEditing }

        if viewModel.selectedTool == .text {
            // Check if clicking on existing object
            if let objectId = viewModel.selectObject(at: location) {
                // Start editing the existing text
                viewModel.startEditing(objectId: objectId)
            } else if isEditing {
                // Currently editing - just commit (deselect) without creating new
                viewModel.deselectAll()
            } else {
                // Not editing anything - create new text object
                let newId = viewModel.addTextObject(at: location)
                viewModel.startEditing(objectId: newId)
            }
        } else if viewModel.selectedTool == .select {
            // Check for double-click
            let isDoubleClick = isDoubleClickDetected(at: location)

            if isDoubleClick {
                // Double-click: start editing text objects or rectangles
                if let objectId = viewModel.selectObject(at: location) {
                    viewModel.startEditing(objectId: objectId)
                }
            } else {
                // Single click: select object or deselect if clicking empty space
                if let objectId = viewModel.selectObject(at: location) {
                    viewModel.selectObjectOnly(id: objectId)
                } else {
                    viewModel.deselectAll()
                }
            }
        } else {
            // For other tools, deselect if clicking empty space
            if viewModel.selectObject(at: location) == nil {
                viewModel.deselectAll()
            }
        }
    }

    private func isDoubleClickDetected(at location: CGPoint) -> Bool {
        let now = Date()
        let doubleClickThreshold: TimeInterval = 0.3
        let distanceThreshold: CGFloat = 10

        defer {
            lastTapTime = now
            lastTapLocation = location
        }

        guard let lastTime = lastTapTime,
              let lastLocation = lastTapLocation else {
            return false
        }

        let timeDiff = now.timeIntervalSince(lastTime)
        let distance = hypot(location.x - lastLocation.x, location.y - lastLocation.y)

        return timeDiff < doubleClickThreshold && distance < distanceThreshold
    }
}
