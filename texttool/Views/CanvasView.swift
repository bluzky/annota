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

    // Panning state (for hand tool and two-finger pan)
    @State private var isPanning: Bool = false
    @State private var lastPanLocation: CGPoint?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Infinite canvas background with dot grid
                InfiniteGridView(viewport: viewModel.viewport)

                // Canvas content with viewport transform
                ZStack {
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
                }
                .scaleEffect(viewModel.viewport.scale, anchor: .topLeading)
                .offset(x: viewModel.viewport.offset.x, y: viewModel.viewport.offset.y)

                // Marquee selection preview (not affected by viewport transform)
                if isMarqueeSelecting,
                   let start = marqueeStart,
                   let end = marqueeEnd {
                    MarqueeView(startPoint: start, currentPoint: end)
                }
            }
            .clipped()
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    handleDragChanged(value, geometry: nil)
                }
                .onEnded { value in
                    handleDragEnded(value)
                }
        )
        .onScrollGesture(
            scroll: { delta in
                // Two-finger trackpad scroll to pan
                viewModel.panViewport(by: CGSize(width: delta.x, height: delta.y))
            },
            magnify: { magnification, location in
                // Pinch-to-zoom around the gesture location
                let factor = 1.0 + magnification
                viewModel.zoomViewport(by: factor, around: location)
            }
        )
        .onContinuousHover { phase in
            updateCursor(for: phase)
        }
    }

    // MARK: - Cursor Management

    private func updateCursor(for phase: HoverPhase) {
        switch phase {
        case .active:
            if viewModel.selectedTool == .hand || isPanning {
                NSCursor.openHand.set()
            } else {
                NSCursor.arrow.set()
            }
        case .ended:
            NSCursor.arrow.set()
        }
    }

    private func handleDragChanged(_ value: DragGesture.Value, geometry: GeometryProxy?) {
        // Handle hand tool panning
        if viewModel.selectedTool == .hand {
            if !isPanning {
                isPanning = true
                lastPanLocation = value.startLocation
                NSCursor.closedHand.set()
            }

            if let lastLocation = lastPanLocation {
                let delta = CGSize(
                    width: value.location.x - lastLocation.x,
                    height: value.location.y - lastLocation.y
                )
                viewModel.panViewport(by: delta)
                lastPanLocation = value.location
            }
            return
        }

        // Convert screen coordinates to canvas coordinates for object operations
        let canvasStart = viewModel.viewport.screenToCanvas(value.startLocation)
        let canvasLocation = viewModel.viewport.screenToCanvas(value.location)

        if viewModel.selectedTool == .rectangle || viewModel.selectedTool == .circle {
            if viewModel.dragStartPoint == nil {
                viewModel.dragStartPoint = canvasStart
            }
            viewModel.currentDragPoint = canvasLocation
        } else if viewModel.selectedTool == .select {
            // Don't drag if an object is being edited
            if viewModel.isAnyObjectEditing {
                return
            }

            // Check if we're starting a new drag
            if draggedObjectId == nil && !isMarqueeSelecting {
                // Check if we started drag on an object (using canvas coordinates)
                if let objectId = viewModel.selectObject(at: canvasStart) {
                    // Dragging an object
                    draggedObjectId = objectId
                    lastDragLocation = canvasLocation

                    // If dragging a non-selected object, select it (unless shift is held)
                    if !viewModel.isSelected(objectId) && !NSEvent.modifierFlags.contains(.shift) {
                        viewModel.selectObjectOnly(id: objectId)
                    }
                } else {
                    // Started drag in empty space - begin marquee selection
                    isMarqueeSelecting = true
                    marqueeStart = value.startLocation  // Keep in screen coords for visual
                    marqueeEnd = value.location
                }
            }

            // Handle object dragging (move all selected objects)
            if let _ = draggedObjectId, let lastLocation = lastDragLocation {
                // Calculate offset in canvas coordinates (accounting for zoom)
                let offset = CGSize(
                    width: canvasLocation.x - lastLocation.x,
                    height: canvasLocation.y - lastLocation.y
                )

                // Move all selected objects
                viewModel.moveSelectedObjects(by: offset)
                lastDragLocation = canvasLocation
            }

            // Handle marquee selection (visual stays in screen coords)
            if isMarqueeSelecting {
                marqueeEnd = value.location
            }
        }
    }

    private func handleDragEnded(_ value: DragGesture.Value) {
        // Handle hand tool panning end
        if viewModel.selectedTool == .hand {
            isPanning = false
            lastPanLocation = nil
            NSCursor.openHand.set()
            return
        }

        let distance = hypot(
            value.location.x - value.startLocation.x,
            value.location.y - value.startLocation.y
        )

        // Handle marquee selection completion
        if isMarqueeSelecting {
            if let start = marqueeStart, let end = marqueeEnd {
                // Convert screen rect to canvas rect for hit testing
                let screenRect = normalizedRect(from: start, to: end)
                let canvasTopLeft = viewModel.viewport.screenToCanvas(CGPoint(x: screenRect.minX, y: screenRect.minY))
                let canvasBottomRight = viewModel.viewport.screenToCanvas(CGPoint(x: screenRect.maxX, y: screenRect.maxY))
                let canvasRect = CGRect(
                    x: canvasTopLeft.x,
                    y: canvasTopLeft.y,
                    width: canvasBottomRight.x - canvasTopLeft.x,
                    height: canvasBottomRight.y - canvasTopLeft.y
                )
                let objectsInMarquee = viewModel.objectsInRect(canvasRect)

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

        // Convert to canvas coordinates
        let canvasStart = viewModel.viewport.screenToCanvas(value.startLocation)
        let canvasLocation = viewModel.viewport.screenToCanvas(value.location)

        // If it's a click (minimal drag)
        if distance < 5 {
            handleClick(at: value.location)
        } else if viewModel.selectedTool == .rectangle {
            // It's a drag for rectangle (use canvas coordinates)
            viewModel.addRectangle(
                from: viewModel.dragStartPoint ?? canvasStart,
                to: canvasLocation
            )
        } else if viewModel.selectedTool == .circle {
            // It's a drag for circle (use canvas coordinates)
            viewModel.addCircle(
                from: viewModel.dragStartPoint ?? canvasStart,
                to: canvasLocation
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

    private func handleClick(at screenLocation: CGPoint) {
        // Convert screen location to canvas coordinates
        let canvasLocation = viewModel.viewport.screenToCanvas(screenLocation)

        // Check if any object is currently being edited
        let isEditing = viewModel.isAnyObjectEditing
        let shiftHeld = NSEvent.modifierFlags.contains(.shift)

        if viewModel.selectedTool == .text {
            // Check if clicking on existing object (using canvas coordinates)
            if let objectId = viewModel.selectObject(at: canvasLocation) {
                // Start editing the existing text
                viewModel.startEditing(objectId: objectId)
            } else if isEditing {
                // Currently editing - just commit (deselect) without creating new
                viewModel.deselectAll()
            } else {
                // Not editing anything - create new text object at canvas location
                let newId = viewModel.addTextObject(at: canvasLocation)
                viewModel.startEditing(objectId: newId)
            }
        } else if viewModel.selectedTool == .select {
            // Check if clicking inside an object that's currently being edited
            if let editing = viewModel.editingObject(), editing.contains(canvasLocation) {
                // Click inside editing object - let NSTextView handle it (cursor positioning)
                return
            }

            // Check for double-click (using screen location for timing)
            let isDoubleClick = isDoubleClickDetected(at: screenLocation)

            if isDoubleClick {
                // Double-click: start editing text objects or rectangles
                if let objectId = viewModel.selectObject(at: canvasLocation) {
                    viewModel.startEditing(objectId: objectId)
                }
            } else {
                // Single click: select or toggle selection
                if let objectId = viewModel.selectObject(at: canvasLocation) {
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
        } else if viewModel.selectedTool == .hand {
            // Hand tool click does nothing
            return
        } else {
            // For other tools, deselect if clicking empty space
            if viewModel.selectObject(at: canvasLocation) == nil {
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

    // MARK: - Magnification (Pinch-to-Zoom)
}
