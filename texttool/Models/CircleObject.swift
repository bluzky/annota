//
//  CircleObject.swift
//  texttool
//
//  Created by Flex on 12/11/25.
//

import SwiftUI

struct CircleObject: CanvasObject, TextContentObject, StrokableObject, FillableObject {
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

    // MARK: - CircleObject Specific
    var autoResizeHeight: Bool

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
        fillOpacity: CGFloat = 0.1
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
    }

    // MARK: - CanvasObject Methods

    func contains(_ point: CGPoint) -> Bool {
        // Transform point to local coordinates if rotated
        let localPoint = rotation != 0 ? transformToLocal(point) : point

        // Calculate distance from center using ellipse equation
        let centerX = position.x + size.width / 2
        let centerY = position.y + size.height / 2
        let radiusX = size.width / 2
        let radiusY = size.height / 2

        // Ellipse equation: ((x-cx)/rx)^2 + ((y-cy)/ry)^2 <= 1
        let dx = (localPoint.x - centerX) / radiusX
        let dy = (localPoint.y - centerY) / radiusY
        return (dx * dx + dy * dy) <= 1
    }

    func boundingBox() -> CGRect {
        CGRect(origin: position, size: size)
    }

    func hitTest(_ point: CGPoint, threshold: CGFloat) -> HitTestResult? {
        // Transform point to local coordinates if rotated
        let localPoint = rotation != 0 ? transformToLocal(point) : point

        let bounds = boundingBox()

        // Check corners first (they have priority for resize handles)
        if let corner = hitTestCorner(point: localPoint, bounds: bounds, threshold: threshold) {
            return .corner(corner)
        }

        // Check if point is on the ellipse edge
        let centerX = position.x + size.width / 2
        let centerY = position.y + size.height / 2
        let radiusX = size.width / 2
        let radiusY = size.height / 2

        let dx = (localPoint.x - centerX) / radiusX
        let dy = (localPoint.y - centerY) / radiusY
        let distanceFromEdge = abs(sqrt(dx * dx + dy * dy) - 1) * min(radiusX, radiusY)

        if distanceFromEdge <= threshold {
            // Determine which edge based on angle
            let angle = atan2(dy * radiusX, dx * radiusY)
            if abs(angle) < .pi / 4 {
                return .edge(.right)
            } else if abs(angle) > 3 * .pi / 4 {
                return .edge(.left)
            } else if angle > 0 {
                return .edge(.bottom)
            } else {
                return .edge(.top)
            }
        }

        // If inside the ellipse, it's a body hit
        if (dx * dx + dy * dy) <= 1 {
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
}
