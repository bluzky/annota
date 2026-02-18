//
//  RectangleObject.swift
//  texttool
//
//  Created by Flex on 12/11/25.
//

import SwiftUI

struct RectangleObject: CanvasObject, TextContentObject, StrokableObject, FillableObject {
    // MARK: - CanvasObject Properties
    let id: UUID
    var position: CGPoint
    var size: CGSize
    var rotation: CGFloat = 0
    var isLocked: Bool = false
    var zIndex: Int = 0

    // MARK: - StrokableObject Properties
    var strokeColor: Color
    var strokeWidth: CGFloat = 2
    var strokeStyle: StrokeStyleType = .solid

    // MARK: - FillableObject Properties
    var fillColor: Color
    var fillOpacity: CGFloat = 0.1

    // MARK: - TextContentObject Properties
    var text: String
    var textAttributes: TextAttributes
    var isEditing: Bool

    // MARK: - RectangleObject Specific
    var autoResizeHeight: Bool
    var cornerRadius: CGFloat = 0

    // MARK: - Backward Compatibility

    /// Convenience accessor for color (backward compatibility - maps to strokeColor)
    var color: Color {
        get { strokeColor }
        set {
            strokeColor = newValue
            fillColor = newValue
        }
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        position: CGPoint,
        size: CGSize,
        color: Color = .black,
        text: String = "",
        isEditing: Bool = false,
        autoResizeHeight: Bool = false,
        rotation: CGFloat = 0,
        isLocked: Bool = false,
        zIndex: Int = 0,
        strokeWidth: CGFloat = 2,
        strokeStyle: StrokeStyleType = .solid,
        fillOpacity: CGFloat = 0.1,
        cornerRadius: CGFloat = 0
    ) {
        self.id = id
        self.position = position
        self.size = size
        self.strokeColor = color
        self.fillColor = color
        self.strokeWidth = strokeWidth
        self.strokeStyle = strokeStyle
        self.fillOpacity = fillOpacity
        self.text = text
        self.textAttributes = TextAttributes.default
        self.isEditing = isEditing
        self.autoResizeHeight = autoResizeHeight
        self.rotation = rotation
        self.isLocked = isLocked
        self.zIndex = zIndex
        self.cornerRadius = cornerRadius
    }

    // MARK: - CanvasObject Methods

    func contains(_ point: CGPoint) -> Bool {
        // Transform point to local coordinates if rotated
        let localPoint = rotation != 0 ? transformToLocal(point) : point

        let bounds = CGRect(origin: position, size: size)
        return bounds.contains(localPoint)
    }

    func boundingBox() -> CGRect {
        CGRect(origin: position, size: size)
    }

    func hitTest(_ point: CGPoint, threshold: CGFloat) -> HitTestResult? {
        // Transform point to local coordinates if rotated
        let localPoint = rotation != 0 ? transformToLocal(point) : point

        let bounds = boundingBox()

        // Check if point is outside the expanded bounds
        let expandedBounds = bounds.insetBy(dx: -threshold, dy: -threshold)
        guard expandedBounds.contains(localPoint) else {
            return nil
        }

        // Check corners first (they have priority)
        if let corner = hitTestCorner(point: localPoint, bounds: bounds, threshold: threshold) {
            return .corner(corner)
        }

        // Check edges
        if let edge = hitTestEdge(point: localPoint, bounds: bounds, threshold: threshold) {
            return .edge(edge)
        }

        // If inside the bounds, it's a body hit
        if bounds.contains(localPoint) {
            return .body
        }

        return nil
    }

    // MARK: - Private Hit Test Helpers

    private func hitTestCorner(point: CGPoint, bounds: CGRect, threshold: CGFloat) -> Corner? {
        let corners: [(Corner, CGPoint)] = [
            (.topLeft, CGPoint(x: bounds.minX, y: bounds.minY)),
            (.topRight, CGPoint(x: bounds.maxX, y: bounds.minY)),
            (.bottomLeft, CGPoint(x: bounds.minX, y: bounds.maxY)),
            (.bottomRight, CGPoint(x: bounds.maxX, y: bounds.maxY))
        ]

        for (corner, cornerPoint) in corners {
            let distance = hypot(point.x - cornerPoint.x, point.y - cornerPoint.y)
            if distance <= threshold {
                return corner
            }
        }

        return nil
    }

    private func hitTestEdge(point: CGPoint, bounds: CGRect, threshold: CGFloat) -> Edge? {
        // Top edge
        if abs(point.y - bounds.minY) <= threshold &&
            point.x >= bounds.minX - threshold &&
            point.x <= bounds.maxX + threshold {
            return .top
        }

        // Bottom edge
        if abs(point.y - bounds.maxY) <= threshold &&
            point.x >= bounds.minX - threshold &&
            point.x <= bounds.maxX + threshold {
            return .bottom
        }

        // Left edge
        if abs(point.x - bounds.minX) <= threshold &&
            point.y >= bounds.minY - threshold &&
            point.y <= bounds.maxY + threshold {
            return .left
        }

        // Right edge
        if abs(point.x - bounds.maxX) <= threshold &&
            point.y >= bounds.minY - threshold &&
            point.y <= bounds.maxY + threshold {
            return .right
        }

        return nil
    }
}
