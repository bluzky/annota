//
//  SelectionBox.swift
//  texttool
//
//  Created by Claude on 2/18/26.
//

import SwiftUI

/// Represents the selection box around one or more selected objects
struct SelectionBox {
    /// Combined bounding box of all selected objects
    let bounds: CGRect

    /// Individual bounding boxes for each selected object
    let individualBounds: [UUID: CGRect]

    /// Whether this is a single selection (enables rotation and edge handles)
    let isSingleSelection: Bool

    /// Rotation of the single selected object (only valid for single selection)
    let rotation: CGFloat

    // MARK: - Computed Properties

    /// Center point of the selection box
    var center: CGPoint {
        CGPoint(x: bounds.midX, y: bounds.midY)
    }

    // MARK: - Handle Positions

    /// Size of resize handles (small square)
    static let handleSize: CGFloat = 8

    /// Size of rotation handles (larger square behind resize handle)
    static let rotationHandleSize: CGFloat = 20

    /// Get position for a corner handle
    func cornerPosition(for corner: Corner) -> CGPoint {
        switch corner {
        case .topLeft:
            return CGPoint(x: bounds.minX, y: bounds.minY)
        case .topRight:
            return CGPoint(x: bounds.maxX, y: bounds.minY)
        case .bottomLeft:
            return CGPoint(x: bounds.minX, y: bounds.maxY)
        case .bottomRight:
            return CGPoint(x: bounds.maxX, y: bounds.maxY)
        }
    }

    /// Get position for an edge handle
    func edgePosition(for edge: Edge) -> CGPoint {
        switch edge {
        case .top:
            return CGPoint(x: bounds.midX, y: bounds.minY)
        case .right:
            return CGPoint(x: bounds.maxX, y: bounds.midY)
        case .bottom:
            return CGPoint(x: bounds.midX, y: bounds.maxY)
        case .left:
            return CGPoint(x: bounds.minX, y: bounds.midY)
        }
    }

    // MARK: - Hit Testing

    /// Result of hit testing the selection box
    enum HitZone: Equatable {
        case move           // Interior - for moving objects
        case corner(Corner) // Corner handle - for diagonal resize
        case edge(Edge)     // Edge handle - for horizontal/vertical resize
        case rotation(Corner) // Rotation handle - for rotating
    }

    /// Hit test a point against the selection box handles and interior
    /// - Parameters:
    ///   - point: The point to test (in canvas coordinates)
    ///   - handleSize: The size of handles (default uses standard size)
    /// - Returns: The hit zone if the point hits something, nil otherwise
    func hitTest(_ point: CGPoint, handleSize: CGFloat = SelectionBox.handleSize) -> HitZone? {
        let resizeRadius = handleSize / 2 + 4
        let rotationRadius = Self.rotationHandleSize / 2

        // Transform point into the selection box's local (unrotated) space
        let localPoint: CGPoint
        if isSingleSelection && rotation != 0 {
            let cx = bounds.midX
            let cy = bounds.midY
            let dx = point.x - cx
            let dy = point.y - cy
            let cosR = cos(-rotation)
            let sinR = sin(-rotation)
            localPoint = CGPoint(
                x: cx + dx * cosR - dy * sinR,
                y: cy + dx * sinR + dy * cosR
            )
        } else {
            localPoint = point
        }

        // Check corner handles first - small resize handle has priority over rotation
        for corner in Corner.allCases {
            let handlePos = cornerPosition(for: corner)
            let distance = hypot(localPoint.x - handlePos.x, localPoint.y - handlePos.y)
            if distance <= resizeRadius {
                return .corner(corner)
            }
        }

        // Check edge handles (span between corners, only for single selection)
        if isSingleSelection {
            let halfH = handleSize / 2
            for edge in Edge.allCases {
                let hitRect: CGRect
                switch edge {
                case .top:
                    hitRect = CGRect(x: bounds.minX + handleSize, y: bounds.minY - halfH,
                                     width: bounds.width - handleSize * 2, height: handleSize)
                case .bottom:
                    hitRect = CGRect(x: bounds.minX + handleSize, y: bounds.maxY - halfH,
                                     width: bounds.width - handleSize * 2, height: handleSize)
                case .left:
                    hitRect = CGRect(x: bounds.minX - halfH, y: bounds.minY + handleSize,
                                     width: handleSize, height: bounds.height - handleSize * 2)
                case .right:
                    hitRect = CGRect(x: bounds.maxX - halfH, y: bounds.minY + handleSize,
                                     width: handleSize, height: bounds.height - handleSize * 2)
                }
                if hitRect.contains(localPoint) {
                    return .edge(edge)
                }
            }
        }

        // Check rotation handles (larger square at corners, shifted outward, only for single selection)
        if isSingleSelection {
            let shift = (Self.rotationHandleSize - handleSize) / 2
            for corner in Corner.allCases {
                let cornerPos = cornerPosition(for: corner)
                // Center of the rotation square is shifted outward from corner
                let cx: CGFloat
                let cy: CGFloat
                switch corner {
                case .topLeft:
                    cx = cornerPos.x - shift; cy = cornerPos.y - shift
                case .topRight:
                    cx = cornerPos.x + shift; cy = cornerPos.y - shift
                case .bottomLeft:
                    cx = cornerPos.x - shift; cy = cornerPos.y + shift
                case .bottomRight:
                    cx = cornerPos.x + shift; cy = cornerPos.y + shift
                }
                let halfSize = Self.rotationHandleSize / 2
                let hitRect = CGRect(x: cx - halfSize, y: cy - halfSize, width: Self.rotationHandleSize, height: Self.rotationHandleSize)
                if hitRect.contains(localPoint) {
                    return .rotation(corner)
                }
            }
        }

        // Check interior for move
        if bounds.contains(localPoint) {
            return .move
        }

        return nil
    }

    // MARK: - Factory

    /// Create a selection box from selected objects
    /// - Parameter objects: The selected canvas objects
    /// - Returns: A SelectionBox, or nil if no objects provided
    static func from(objects: [AnyCanvasObject]) -> SelectionBox? {
        guard !objects.isEmpty else { return nil }

        var minX = CGFloat.infinity
        var minY = CGFloat.infinity
        var maxX = -CGFloat.infinity
        var maxY = -CGFloat.infinity

        var individualBounds: [UUID: CGRect] = [:]

        for obj in objects {
            let bbox = obj.boundingBox()
            individualBounds[obj.id] = bbox

            minX = min(minX, bbox.minX)
            minY = min(minY, bbox.minY)
            maxX = max(maxX, bbox.maxX)
            maxY = max(maxY, bbox.maxY)
        }

        let bounds = CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )

        let isSingleSelection = objects.count == 1
        let rotation = isSingleSelection ? objects[0].rotation : 0

        return SelectionBox(
            bounds: bounds,
            individualBounds: individualBounds,
            isSingleSelection: isSingleSelection,
            rotation: rotation
        )
    }

    // MARK: - Coordinate Conversion

    /// Convert this selection box from canvas coordinates to screen coordinates
    func toScreen(viewport: ViewportState) -> SelectionBox {
        let screenOrigin = viewport.canvasToScreen(CGPoint(x: bounds.minX, y: bounds.minY))
        let screenEnd = viewport.canvasToScreen(CGPoint(x: bounds.maxX, y: bounds.maxY))
        let screenBounds = CGRect(
            x: screenOrigin.x,
            y: screenOrigin.y,
            width: screenEnd.x - screenOrigin.x,
            height: screenEnd.y - screenOrigin.y
        )

        var screenIndividualBounds: [UUID: CGRect] = [:]
        for (id, rect) in individualBounds {
            let origin = viewport.canvasToScreen(CGPoint(x: rect.minX, y: rect.minY))
            let end = viewport.canvasToScreen(CGPoint(x: rect.maxX, y: rect.maxY))
            screenIndividualBounds[id] = CGRect(
                x: origin.x, y: origin.y,
                width: end.x - origin.x, height: end.y - origin.y
            )
        }

        return SelectionBox(
            bounds: screenBounds,
            individualBounds: screenIndividualBounds,
            isSingleSelection: isSingleSelection,
            rotation: rotation
        )
    }
}
