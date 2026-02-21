//
//  CanvasObject.swift
//  texttool
//
//  Created by Claude on 2/18/26.
//

import SwiftUI

/// Base protocol for all objects that can be placed on the canvas
protocol CanvasObject: Identifiable {
    /// Unique identifier for the object
    var id: UUID { get }

    /// Position of the object (top-left corner of bounding box)
    var position: CGPoint { get set }

    /// Size of the object's bounding box
    var size: CGSize { get set }

    /// Rotation angle in radians
    var rotation: CGFloat { get set }

    /// Whether the object is locked from editing
    var isLocked: Bool { get set }

    /// Z-index for rendering order (higher values render on top)
    var zIndex: Int { get set }

    /// Check if a point is contained within this object
    /// - Parameter point: The point to test in canvas coordinates
    /// - Returns: true if the point is within the object
    func contains(_ point: CGPoint) -> Bool

    /// Get the bounding box of this object
    /// - Returns: The bounding rectangle in canvas coordinates
    func boundingBox() -> CGRect

    /// Perform a detailed hit test to determine which part of the object was hit
    /// - Parameters:
    ///   - point: The point to test in canvas coordinates
    ///   - threshold: The tolerance distance for edge/corner detection
    /// - Returns: The hit test result, or nil if the point is outside the object
    func hitTest(_ point: CGPoint, threshold: CGFloat) -> HitTestResult?

    /// Whether this object uses control points for interaction instead of a selection box.
    /// Objects that return true (e.g. lines) show control-point handles rather than a bounding-box overlay.
    var usesControlPoints: Bool { get }
}

// MARK: - Default Implementations

extension CanvasObject {
    var usesControlPoints: Bool { false }

    /// Default bounding box implementation based on position and size
    func boundingBox() -> CGRect {
        CGRect(origin: position, size: size)
    }

    /// Default hit test implementation.
    /// Transforms the test point into object-local space before testing against the bounding box,
    /// so rotated objects are hit-tested correctly.
    func hitTest(_ point: CGPoint, threshold: CGFloat) -> HitTestResult? {
        // Transform the point into local (unrotated) space
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

    /// Test if a point hits a corner of the bounding box
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

    /// Test if a point hits an edge of the bounding box
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

// MARK: - Rotation Transform Helpers

extension CanvasObject {
    /// The center point of this object
    var center: CGPoint {
        CGPoint(
            x: position.x + size.width / 2,
            y: position.y + size.height / 2
        )
    }

    /// Transform a point from canvas coordinates to object-local coordinates,
    /// accounting for rotation
    func transformToLocal(_ point: CGPoint) -> CGPoint {
        guard rotation != 0 else { return point }

        let center = self.center
        let dx = point.x - center.x
        let dy = point.y - center.y

        // Rotate the point in the opposite direction
        let cos_r = cos(-rotation)
        let sin_r = sin(-rotation)

        return CGPoint(
            x: center.x + dx * cos_r - dy * sin_r,
            y: center.y + dx * sin_r + dy * cos_r
        )
    }

    /// Transform a point from object-local coordinates to canvas coordinates,
    /// accounting for rotation
    func transformToCanvas(_ point: CGPoint) -> CGPoint {
        guard rotation != 0 else { return point }

        let center = self.center
        let dx = point.x - center.x
        let dy = point.y - center.y

        let cos_r = cos(rotation)
        let sin_r = sin(rotation)

        return CGPoint(
            x: center.x + dx * cos_r - dy * sin_r,
            y: center.y + dx * sin_r + dy * cos_r
        )
    }
}
