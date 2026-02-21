//
//  CanvasView.swift
//  texttool
//
//  Created by Flex on 12/11/25.
//

import SwiftUI

struct CanvasView: View {
    @ObservedObject var viewModel: CanvasViewModel
    private let toolRegistry = ToolRegistry.shared
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

    // Resize handle state
    @State private var activeHandleZone: SelectionBox.HitZone?
    @State private var resizeAnchor: CGPoint?
    @State private var initialObjectFrames: [UUID: CGRect] = [:]

    // Rotation state
    @State private var initialRotation: CGFloat = 0
    @State private var rotationStartAngle: CGFloat = 0
    @State private var rotationCenter: CGPoint = .zero
    @State private var initialObjectRotations: [UUID: CGFloat] = [:]
    @State private var initialObjectPositions: [UUID: CGPoint] = [:]

    // Line control point drag state
    @State private var draggingControlPointIndex: Int?
    @State private var draggingControlPointObjectId: UUID?

    // Current hover position (screen coordinates, relative to CanvasView)
    @State private var currentHoverLocation: CGPoint?
    @State private var canvasSize: CGSize = .zero

    // Keyboard event monitor
    @State private var keyMonitor: Any?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Infinite canvas background with dot grid
                InfiniteGridView(viewport: viewModel.viewport)

                // Canvas content with viewport transform
                ZStack {
                    // Render all objects in zIndex order via CanvasObjectView dispatcher
                    ForEach(viewModel.objects) { obj in
                        CanvasObjectView(
                            object: obj,
                            isSelected: viewModel.isSelected(obj.id),
                            viewModel: viewModel
                        )
                    }

                    // Tool drag preview (dispatched via ToolRegistry)
                    if let start = viewModel.dragStartPoint,
                       let current = viewModel.currentDragPoint,
                       let tool = toolRegistry.tool(for: viewModel.selectedTool) {
                        tool.renderPreview(
                            start: start,
                            current: current,
                            viewModel: viewModel
                        )
                    }

                }
                .scaleEffect(viewModel.viewport.scale, anchor: .topLeading)
                .offset(x: viewModel.viewport.offset.x, y: viewModel.viewport.offset.y)

                // Selection box overlay (rendered in screen coordinates, not affected by viewport)
                // Hidden during active resize or rotation drag, and for line-only selections
                if activeHandleZone == nil,
                   let selectionBox = viewModel.selectionBox,
                   viewModel.selectedTool == .select,
                   !viewModel.isAnyObjectEditing,
                   !viewModel.isControlPointOnlySelection {
                    let screenBox = selectionBox.toScreen(viewport: viewModel.viewport)
                    SelectionBoxView(
                        selectionBox: screenBox,
                        viewModel: viewModel
                    )
                }

                // Marquee selection preview (not affected by viewport transform)
                if isMarqueeSelecting,
                   let start = marqueeStart,
                   let end = marqueeEnd {
                    MarqueeView(startPoint: start, currentPoint: end)
                }
            }
            .clipped()
            .onAppear {
                canvasSize = geometry.size
                installKeyMonitor()
            }
            .onDisappear {
                if let monitor = keyMonitor {
                    NSEvent.removeMonitor(monitor)
                    keyMonitor = nil
                }
            }
            .onChange(of: geometry.size) { _, newSize in canvasSize = newSize }
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
        .onScrollGesture(
            scroll: { delta in
                // Two-finger trackpad scroll to pan
                viewModel.panViewport(by: CGSize(width: delta.x, height: delta.y))
            },
            magnify: { magnification, _ in
                let anchor = currentHoverLocation ?? CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                let factor = 1.0 + magnification
                viewModel.zoomViewport(by: factor, around: anchor)
            },
            scrollZoom: { zoomDelta, _ in
                let anchor = currentHoverLocation ?? CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                let factor = 1.0 + zoomDelta
                viewModel.zoomViewport(by: factor, around: anchor)
            }
        )
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                currentHoverLocation = location
            case .ended:
                currentHoverLocation = nil
            }
            updateCursor(for: phase)
        }
    }

    // MARK: - Cursor Management

    private func updateCursor(for phase: HoverPhase) {
        switch phase {
        case .active(let screenLocation):
            if viewModel.selectedTool == .hand || isPanning {
                NSCursor.openHand.set()
            } else if viewModel.isAnyObjectEditing {
                NSCursor.iBeam.set()
            } else if viewModel.selectedTool == .select,
                      viewModel.isControlPointOnlySelection {
                let canvasPoint = viewModel.viewport.screenToCanvas(screenLocation)
                if hitTestLineControlPoint(at: canvasPoint) != nil {
                    NSCursor.arrow.set()
                } else if hitTestLineBody(at: canvasPoint) {
                    NSCursor.openHand.set()
                } else {
                    NSCursor.arrow.set()
                }
            } else if viewModel.selectedTool == .select,
                      let selectionBox = viewModel.selectionBox {
                let canvasPoint = viewModel.viewport.screenToCanvas(screenLocation)
                if let hitZone = selectionBox.hitTest(canvasPoint) {
                    cursorForHitZone(hitZone).set()
                } else {
                    NSCursor.arrow.set()
                }
            } else if viewModel.selectedTool == .text {
                NSCursor.iBeam.set()
            } else if viewModel.selectedTool.isLineTool {
                NSCursor.crosshair.set()
            } else {
                NSCursor.arrow.set()
            }
        case .ended:
            NSCursor.arrow.set()
        }
    }

    private func cursorForHitZone(_ zone: SelectionBox.HitZone) -> NSCursor {
        switch zone {
        case .move:
            return NSCursor.openHand
        case .corner(let corner):
            switch corner {
            case .topLeft, .bottomRight:
                return Self.nwseResizeCursor
            case .topRight, .bottomLeft:
                return Self.neswResizeCursor
            }
        case .edge(let edge):
            switch edge {
            case .top, .bottom:
                return NSCursor.resizeUpDown
            case .left, .right:
                return NSCursor.resizeLeftRight
            }
        case .rotation:
            return Self.rotateCursor
        }
    }

    // Diagonal resize cursors (macOS doesn't provide these built-in)
    private static let nwseResizeCursor: NSCursor = {
        if let image = NSImage(systemSymbolName: "arrow.up.left.and.arrow.down.right", accessibilityDescription: "Resize NW-SE") {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            let configured = image.withSymbolConfiguration(config) ?? image
            return NSCursor(image: configured, hotSpot: NSPoint(x: 8, y: 8))
        }
        return NSCursor.crosshair
    }()

    private static let neswResizeCursor: NSCursor = {
        if let image = NSImage(systemSymbolName: "arrow.down.left.and.arrow.up.right", accessibilityDescription: "Resize NE-SW") {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            let configured = image.withSymbolConfiguration(config) ?? image
            return NSCursor(image: configured, hotSpot: NSPoint(x: 8, y: 8))
        }
        return NSCursor.crosshair
    }()

    private static let rotateCursor: NSCursor = {
        if let image = NSImage(systemSymbolName: "arrow.trianglehead.2.counterclockwise.rotate.90", accessibilityDescription: "Rotate") {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            let configured = image.withSymbolConfiguration(config) ?? image
            return NSCursor(image: configured, hotSpot: NSPoint(x: 8, y: 8))
        }
        return NSCursor.crosshair
    }()

    private func handleDragChanged(_ value: DragGesture.Value) {
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

        // Delegate to registered tool plugin (shape, line, arrow, text, etc.)
        if let tool = toolRegistry.tool(for: viewModel.selectedTool) {
            tool.handleDragChanged(
                start: canvasStart,
                current: canvasLocation,
                viewModel: viewModel
            )
            return
        }

        if viewModel.selectedTool == .select {
            // Don't drag if an object is being edited
            if viewModel.isAnyObjectEditing {
                return
            }

            // Check if we're starting a new drag
            if draggedObjectId == nil && !isMarqueeSelecting && activeHandleZone == nil && draggingControlPointIndex == nil {
                // First check if we hit a line object's control point
                if let (lineId, cpIndex) = hitTestLineControlPoint(at: canvasStart) {
                    draggingControlPointObjectId = lineId
                    draggingControlPointIndex = cpIndex
                    if !viewModel.isSelected(lineId) {
                        viewModel.selectObjectOnly(id: lineId)
                    }
                    lastDragLocation = canvasLocation
                }
                // Then check if we started drag on a selection box handle (skip for line-only selections)
                else if !viewModel.isControlPointOnlySelection,
                   let selectionBox = viewModel.selectionBox,
                   let hitZone = selectionBox.hitTest(canvasStart) {
                    switch hitZone {
                    case .corner, .edge:
                        // Start resize
                        activeHandleZone = hitZone
                        resizeAnchor = anchorPoint(for: hitZone, in: selectionBox)
                        initialRotation = selectionBox.rotation
                        rotationCenter = selectionBox.center
                        // Store initial frames for all selected objects
                        initialObjectFrames = [:]
                        for obj in viewModel.selectedObjects {
                            initialObjectFrames[obj.id] = obj.boundingBox()
                        }
                        lastDragLocation = canvasLocation
                        cursorForHitZone(hitZone).set()
                    case .rotation:
                        activeHandleZone = hitZone
                        // Use the selection box center as the rotation pivot
                        rotationCenter = selectionBox.center
                        initialRotation = selectionBox.rotation
                        rotationStartAngle = atan2(canvasLocation.y - rotationCenter.y, canvasLocation.x - rotationCenter.x)
                        // Store initial per-object state for orbit math
                        initialObjectPositions = [:]
                        initialObjectRotations = [:]
                        initialObjectFrames = [:]
                        for obj in viewModel.selectedObjects {
                            let bbox = obj.boundingBox()
                            initialObjectPositions[obj.id] = CGPoint(x: bbox.midX, y: bbox.midY)
                            initialObjectRotations[obj.id] = obj.rotation
                            initialObjectFrames[obj.id] = bbox
                        }
                        lastDragLocation = canvasLocation
                    case .move:
                        // Start moving via selection box interior
                        draggedObjectId = viewModel.selectedIds.first
                        lastDragLocation = canvasLocation
                    }
                } else if let objectId = viewModel.selectObject(at: canvasStart) {
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

            // Handle line control point dragging
            if let cpIndex = draggingControlPointIndex,
               let objId = draggingControlPointObjectId {
                let shiftHeld = NSEvent.modifierFlags.contains(.shift)
                viewModel.updateLineObject(withId: objId) { line in
                    let newPoint: CGPoint
                    if shiftHeld {
                        let anchor = cpIndex == 0 ? line.endPoint : line.startPoint
                        newPoint = constrainToAngle(from: anchor, to: canvasLocation)
                    } else {
                        newPoint = canvasLocation
                    }
                    if cpIndex == 0 {
                        line.startPoint = newPoint
                    } else {
                        line.endPoint = newPoint
                    }
                }
                return
            }

            // Handle resize / rotation dragging via a single switch on the active handle zone
            if let handleZone = activeHandleZone {
                switch handleZone {
                case .corner, .edge:
                    if let anchor = resizeAnchor {
                        handleResize(zone: handleZone, canvasLocation: canvasLocation, anchor: anchor)
                    }
                    return
                case .rotation:
                    let currentAngle = atan2(canvasLocation.y - rotationCenter.y, canvasLocation.x - rotationCenter.x)
                    var angleDelta = currentAngle - rotationStartAngle
                    // Shift+rotate snaps to 15° increments
                    if NSEvent.modifierFlags.contains(.shift) {
                        let snapAngle = CGFloat.pi / 12 // 15 degrees
                        angleDelta = ((initialRotation + angleDelta) / snapAngle).rounded() * snapAngle - initialRotation
                    }
                    for id in viewModel.selectedIds {
                        let objInitialRotation = initialObjectRotations[id] ?? 0
                        let newRotation = objInitialRotation + angleDelta
                        // Orbit each object's center around the group center, then convert back to origin
                        if let initialCenter = initialObjectPositions[id],
                           let bbox = initialObjectFrames[id] {
                            let newCenter = rotatePoint(initialCenter, around: rotationCenter, by: angleDelta)
                            let newOrigin = CGPoint(x: newCenter.x - bbox.width / 2, y: newCenter.y - bbox.height / 2)
                            viewModel.updateObjectPositionAndRotation(id: id, position: newOrigin, rotation: newRotation)
                        } else {
                            viewModel.updateObjectRotation(id: id, rotation: newRotation)
                        }
                    }
                    return
                case .move:
                    break  // falls through to object-drag logic below
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

    // MARK: - Resize Logic

    /// Get the anchor point (opposite corner/edge) for a resize operation
    private func anchorPoint(for zone: SelectionBox.HitZone, in selectionBox: SelectionBox) -> CGPoint {
        switch zone {
        case .corner(let corner):
            return selectionBox.cornerPosition(for: corner.opposite)
        case .edge(let edge):
            return selectionBox.edgePosition(for: edge.opposite)
        default:
            return selectionBox.center
        }
    }

    /// Handle resize by computing new frames for all selected objects
    private func handleResize(zone: SelectionBox.HitZone, canvasLocation: CGPoint, anchor: CGPoint) {
        guard !initialObjectFrames.isEmpty else { return }

        // Compute the original bounding box of all selected objects
        var origMinX = CGFloat.infinity, origMinY = CGFloat.infinity
        var origMaxX = -CGFloat.infinity, origMaxY = -CGFloat.infinity
        for (_, frame) in initialObjectFrames {
            origMinX = min(origMinX, frame.minX)
            origMinY = min(origMinY, frame.minY)
            origMaxX = max(origMaxX, frame.maxX)
            origMaxY = max(origMaxY, frame.maxY)
        }
        let origWidth = origMaxX - origMinX
        let origHeight = origMaxY - origMinY

        guard origWidth > 0 && origHeight > 0 else { return }

        // For rotated objects, un-rotate the drag point into local space around the object center
        let localDragPoint: CGPoint
        if initialRotation != 0 {
            let cx = rotationCenter.x
            let cy = rotationCenter.y
            let dx = canvasLocation.x - cx
            let dy = canvasLocation.y - cy
            let cosR = cos(-initialRotation)
            let sinR = sin(-initialRotation)
            localDragPoint = CGPoint(
                x: cx + dx * cosR - dy * sinR,
                y: cy + dx * sinR + dy * cosR
            )
        } else {
            localDragPoint = canvasLocation
        }

        // Compute new bounding box based on anchor + drag point
        var newMinX: CGFloat, newMinY: CGFloat, newMaxX: CGFloat, newMaxY: CGFloat

        let aspectRatio = origWidth / origHeight

        switch zone {
        case .corner:
            let dx = localDragPoint.x - anchor.x
            let dy = localDragPoint.y - anchor.y

            // Determine sign from actual drag direction so flipping works
            let signX: CGFloat = dx >= 0 ? 1 : -1
            let signY: CGFloat = dy >= 0 ? 1 : -1

            let absDx = abs(dx)
            let absDy = abs(dy)

            let newWidth: CGFloat
            let newHeight: CGFloat
            // Shift+drag keeps aspect ratio; default is free resize
            if NSEvent.modifierFlags.contains(.shift) {
                if absDx / aspectRatio > absDy {
                    newWidth = max(absDx, 10)
                    newHeight = newWidth / aspectRatio
                } else {
                    newHeight = max(absDy, 10)
                    newWidth = newHeight * aspectRatio
                }
            } else {
                newWidth = max(absDx, 10)
                newHeight = max(absDy, 10)
            }

            if signX > 0 {
                newMinX = anchor.x
                newMaxX = anchor.x + newWidth
            } else {
                newMinX = anchor.x - newWidth
                newMaxX = anchor.x
            }
            if signY > 0 {
                newMinY = anchor.y
                newMaxY = anchor.y + newHeight
            } else {
                newMinY = anchor.y - newHeight
                newMaxY = anchor.y
            }
        case .edge(let edge):
            switch edge {
            case .left, .right:
                newMinX = min(anchor.x, localDragPoint.x)
                newMaxX = max(anchor.x, localDragPoint.x)
                newMinY = origMinY
                newMaxY = origMaxY
            case .top, .bottom:
                newMinX = origMinX
                newMaxX = origMaxX
                newMinY = min(anchor.y, localDragPoint.y)
                newMaxY = max(anchor.y, localDragPoint.y)
            }
        default:
            return
        }

        let newWidth = newMaxX - newMinX
        let newHeight = newMaxY - newMinY

        guard newWidth > 5 && newHeight > 5 else { return }  // Minimum size

        // Apply scaled position and size to each selected object
        for (id, origFrame) in initialObjectFrames {
            let relX = (origFrame.minX - origMinX) / origWidth
            let relY = (origFrame.minY - origMinY) / origHeight
            let relW = origFrame.width / origWidth
            let relH = origFrame.height / origHeight

            var newObjX = newMinX + relX * newWidth
            var newObjY = newMinY + relY * newHeight
            let newObjW = relW * newWidth
            let newObjH = relH * newHeight

            guard newObjW > 1 && newObjH > 1 else { continue }

            // For rotated objects, adjust position so the anchor stays fixed in world space.
            // The anchor point is in local (unrotated) space. We need its world-space position
            // (rotated around the object center) to remain the same after the resize.
            if initialRotation != 0 {
                let oldCenter = CGPoint(
                    x: origFrame.minX + origFrame.width / 2,
                    y: origFrame.minY + origFrame.height / 2
                )
                let newCenter = CGPoint(
                    x: newObjX + newObjW / 2,
                    y: newObjY + newObjH / 2
                )

                // The anchor in local space relative to old object
                let localAnchor = anchor
                // Anchor's world position with old frame
                let oldAnchorWorld = rotatePoint(localAnchor, around: oldCenter, by: initialRotation)
                // Anchor's world position with new frame
                let newAnchorWorld = rotatePoint(localAnchor, around: newCenter, by: initialRotation)

                // Shift new position to compensate
                newObjX += oldAnchorWorld.x - newAnchorWorld.x
                newObjY += oldAnchorWorld.y - newAnchorWorld.y
            }

            viewModel.updateObjectFrame(
                id: id,
                position: CGPoint(x: newObjX, y: newObjY),
                size: CGSize(width: newObjW, height: newObjH)
            )
        }
    }

    /// Rotate a point around a center by an angle (radians)
    private func rotatePoint(_ point: CGPoint, around center: CGPoint, by angle: CGFloat) -> CGPoint {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let cosA = cos(angle)
        let sinA = sin(angle)
        return CGPoint(
            x: center.x + dx * cosA - dy * sinA,
            y: center.y + dx * sinA + dy * cosA
        )
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
        } else if let tool = toolRegistry.tool(for: viewModel.selectedTool) {
            // Delegate drag-end to registered tool plugin
            let start = viewModel.dragStartPoint ?? canvasStart
            let shiftHeld = NSEvent.modifierFlags.contains(.shift)
            tool.handleDragEnded(
                start: start,
                end: canvasLocation,
                viewModel: viewModel,
                shiftHeld: shiftHeld
            )
        }

        // Reset drag state
        viewModel.dragStartPoint = nil
        viewModel.currentDragPoint = nil
        draggedObjectId = nil
        lastDragLocation = nil
        activeHandleZone = nil
        resizeAnchor = nil
        draggingControlPointIndex = nil
        draggingControlPointObjectId = nil
        initialObjectFrames = [:]
        initialRotation = 0
        rotationStartAngle = 0
        rotationCenter = .zero
        initialObjectRotations = [:]
        initialObjectPositions = [:]
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

        let shiftHeld = NSEvent.modifierFlags.contains(.shift)

        // Delegate to registered tool plugin for click handling
        if let tool = toolRegistry.tool(for: viewModel.selectedTool) {
            tool.handleClick(at: canvasLocation, viewModel: viewModel, shiftHeld: shiftHeld)
            return
        }

        if viewModel.selectedTool == .select {
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

    // MARK: - Keyboard Shortcuts

    private func installKeyMonitor() {
        // Guard against double-install if onAppear fires more than once.
        // A second monitor would leak a strong capture of viewModel.
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Let text fields handle their own keyboard input
            if viewModel.isAnyObjectEditing {
                return event
            }

            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // Cmd+C: Copy
            if modifiers == .command && event.charactersIgnoringModifiers == "c" {
                viewModel.copySelection()
                return nil
            }

            // Cmd+X: Cut
            if modifiers == .command && event.charactersIgnoringModifiers == "x" {
                viewModel.cutSelection()
                return nil
            }

            // Cmd+V: Paste
            if modifiers == .command && event.charactersIgnoringModifiers == "v" {
                viewModel.pasteFromClipboard(viewportSize: canvasSize)
                return nil
            }

            // Delete (keyCode 51) or Forward Delete (keyCode 117)
            if modifiers.isEmpty && (event.keyCode == 51 || event.keyCode == 117) {
                if viewModel.selectionState.hasSelection {
                    viewModel.deleteSelected()
                    return nil
                }
            }

            return event
        }
    }

    // MARK: - Line Control Point Hit Testing

    /// Check if a canvas point hits a control point on any selected line object
    /// Returns (objectId, controlPointIndex) or nil
    private func hitTestLineControlPoint(at point: CGPoint, threshold: CGFloat = 8) -> (UUID, Int)? {
        for obj in viewModel.selectedObjects {
            guard let line = obj.asLineObject else { continue }
            if hypot(point.x - line.startPoint.x, point.y - line.startPoint.y) <= threshold {
                return (line.id, 0)
            }
            if hypot(point.x - line.endPoint.x, point.y - line.endPoint.y) <= threshold {
                return (line.id, 1)
            }
        }
        return nil
    }

    /// Check if a canvas point is near the body of any selected line object
    private func hitTestLineBody(at point: CGPoint, threshold: CGFloat = 8) -> Bool {
        for obj in viewModel.selectedObjects {
            guard let line = obj.asLineObject else { continue }
            if line.contains(point) {
                return true
            }
        }
        return false
    }

    // MARK: - Line Angle Constraint

    /// Constrain endpoint to nearest 45-degree angle from start
    private func constrainToAngle(from start: CGPoint, to end: CGPoint) -> CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let distance = hypot(dx, dy)
        let angle = atan2(dy, dx)
        // Snap to nearest 15-degree (pi/12)
        let snapAngle = CGFloat.pi / 12
        let snappedAngle = (angle / snapAngle).rounded() * snapAngle
        return CGPoint(
            x: start.x + distance * cos(snappedAngle),
            y: start.y + distance * sin(snappedAngle)
        )
    }

    // MARK: - Magnification (Pinch-to-Zoom)
}
