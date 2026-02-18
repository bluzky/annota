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

    // Marquee selection state
    @State private var isMarqueeSelecting: Bool = false
    @State private var marqueeStart: CGPoint?
    @State private var marqueeEnd: CGPoint?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background - white canvas
                Color.white

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
                        isSelected: viewModel.isSelected(rectObj.id),
                        viewModel: viewModel
                    )
                }

                // Render circle objects
                ForEach(viewModel.circleObjects) { circleObj in
                    CircleObjectView(
                        object: circleObj,
                        isSelected: viewModel.isSelected(circleObj.id),
                        viewModel: viewModel
                    )
                }

                // Render text objects
                ForEach(viewModel.textObjects) { textObj in
                    TextObjectView(
                        object: textObj,
                        viewModel: viewModel,
                        isSelected: viewModel.isSelected(textObj.id)
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

                // Marquee selection preview
                if isMarqueeSelecting,
                   let start = marqueeStart,
                   let end = marqueeEnd {
                    MarqueeView(startPoint: start, currentPoint: end)
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
            // Don't drag if an object is being edited
            if viewModel.isAnyObjectEditing {
                return
            }

            // Check if we're starting a new drag
            if draggedObjectId == nil && !isMarqueeSelecting {
                // Check if we started drag on an object
                if let objectId = viewModel.selectObject(at: value.startLocation) {
                    // Dragging an object
                    draggedObjectId = objectId
                    lastDragLocation = value.startLocation

                    // If dragging a non-selected object, select it (unless shift is held)
                    if !viewModel.isSelected(objectId) && !NSEvent.modifierFlags.contains(.shift) {
                        viewModel.selectObjectOnly(id: objectId)
                    }
                } else {
                    // Started drag in empty space - begin marquee selection
                    isMarqueeSelecting = true
                    marqueeStart = value.startLocation
                    marqueeEnd = value.location
                }
            }

            // Handle object dragging (move all selected objects)
            if let _ = draggedObjectId, let lastLocation = lastDragLocation {
                let offset = CGSize(
                    width: value.location.x - lastLocation.x,
                    height: value.location.y - lastLocation.y
                )

                // Move all selected objects
                viewModel.moveSelectedObjects(by: offset)
                lastDragLocation = value.location
            }

            // Handle marquee selection
            if isMarqueeSelecting {
                marqueeEnd = value.location
            }
        }
    }

    private func handleDragEnded(_ value: DragGesture.Value) {
        let distance = hypot(
            value.location.x - value.startLocation.x,
            value.location.y - value.startLocation.y
        )

        // Handle marquee selection completion
        if isMarqueeSelecting {
            if let start = marqueeStart, let end = marqueeEnd {
                let rect = normalizedRect(from: start, to: end)
                let objectsInMarquee = viewModel.objectsInRect(rect)

                let shiftHeld = NSEvent.modifierFlags.contains(.shift)
                if shiftHeld {
                    // Add to existing selection
                    viewModel.addMultipleToSelection(ids: objectsInMarquee)
                } else {
                    // Replace selection
                    viewModel.selectMultiple(ids: objectsInMarquee)
                }
            }

            // Reset marquee state
            isMarqueeSelecting = false
            marqueeStart = nil
            marqueeEnd = nil
            return
        }

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

    /// Compute normalized rectangle from two points
    private func normalizedRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        let x = min(start.x, end.x)
        let y = min(start.y, end.y)
        let width = abs(end.x - start.x)
        let height = abs(end.y - start.y)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func handleClick(at location: CGPoint) {
        // Check if any object is currently being edited
        let isEditing = viewModel.isAnyObjectEditing
        let shiftHeld = NSEvent.modifierFlags.contains(.shift)

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
            // Check if clicking inside an object that's currently being edited
            if let editing = viewModel.editingObject(), editing.contains(location) {
                // Click inside editing object - let NSTextView handle it (cursor positioning)
                return
            }

            // Check for double-click
            let isDoubleClick = isDoubleClickDetected(at: location)

            if isDoubleClick {
                // Double-click: start editing text objects or rectangles
                if let objectId = viewModel.selectObject(at: location) {
                    viewModel.startEditing(objectId: objectId)
                }
            } else {
                // Single click: select or toggle selection
                if let objectId = viewModel.selectObject(at: location) {
                    if shiftHeld {
                        // Shift+click: toggle selection of this object
                        viewModel.toggleObjectSelection(id: objectId)
                    } else {
                        // Normal click: select only this object
                        viewModel.selectObjectOnly(id: objectId)
                    }
                } else {
                    // Clicked empty space
                    if !shiftHeld {
                        // Without shift, clear selection
                        viewModel.deselectAll()
                    }
                    // With shift held, keep existing selection
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
