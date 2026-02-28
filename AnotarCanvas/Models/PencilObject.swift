//
//  PencilObject.swift
//  AnotarCanvas
//

import SwiftUI

/// A freehand pencil stroke stored as a series of canvas-coordinate points.
/// The path is rendered using Catmull-Rom spline smoothing for a natural look.
public struct PencilObject: CanvasObject, StrokableObject, CopyableCanvasObject {

    // MARK: - CanvasObject Properties

    public let id: UUID
    public var rotation: CGFloat = 0
    public var isLocked: Bool = false
    public var zIndex: Int = 0

    // MARK: - Stroke Points

    /// Raw sampled points in canvas coordinates, in drawing order.
    public var points: [CGPoint]

    // MARK: - StrokableObject Properties

    public var strokeColor: Color = .black
    public var strokeWidth: CGFloat = 2
    public var strokeStyle: StrokeStyleType = .solid

    // MARK: - Computed Properties

    public var usesControlPoints: Bool { false }

    /// Bounding box of all stroke points (plus half stroke width for hit padding).
    private var pointsBounds: CGRect {
        guard !points.isEmpty else { return .zero }
        var minX = points[0].x
        var minY = points[0].y
        var maxX = points[0].x
        var maxY = points[0].y
        for p in points.dropFirst() {
            if p.x < minX { minX = p.x }
            if p.y < minY { minY = p.y }
            if p.x > maxX { maxX = p.x }
            if p.y > maxY { maxY = p.y }
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Position is the top-left corner of the bounding box.
    public var position: CGPoint {
        get { pointsBounds.origin }
        set {
            let dx = newValue.x - position.x
            let dy = newValue.y - position.y
            for i in points.indices {
                points[i].x += dx
                points[i].y += dy
            }
        }
    }

    /// Size is the width/height of the bounding box.
    public var size: CGSize {
        get { pointsBounds.size }
        set {
            let current = pointsBounds
            guard current.width > 0, current.height > 0 else { return }
            let scaleX = newValue.width / current.width
            let scaleY = newValue.height / current.height
            let origin = current.origin
            for i in points.indices {
                points[i] = CGPoint(
                    x: origin.x + (points[i].x - origin.x) * scaleX,
                    y: origin.y + (points[i].y - origin.y) * scaleY
                )
            }
        }
    }

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        points: [CGPoint],
        strokeColor: Color = .black,
        strokeWidth: CGFloat = 2,
        strokeStyle: StrokeStyleType = .solid,
        rotation: CGFloat = 0,
        isLocked: Bool = false,
        zIndex: Int = 0
    ) {
        self.id = id
        self.points = points
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
        self.strokeStyle = strokeStyle
        self.rotation = rotation
        self.isLocked = isLocked
        self.zIndex = zIndex
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case id, points, rotation, isLocked, zIndex
        case strokeColor, strokeWidth, strokeStyle
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        points = try container.decode([CGPoint].self, forKey: .points)
        rotation = try container.decodeIfPresent(CGFloat.self, forKey: .rotation) ?? 0
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        zIndex = try container.decodeIfPresent(Int.self, forKey: .zIndex) ?? 0
        let codableStroke = try container.decode(CodableColor.self, forKey: .strokeColor)
        strokeColor = codableStroke.color
        strokeWidth = try container.decodeIfPresent(CGFloat.self, forKey: .strokeWidth) ?? 2
        strokeStyle = try container.decodeIfPresent(StrokeStyleType.self, forKey: .strokeStyle) ?? .solid
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(points, forKey: .points)
        try container.encode(rotation, forKey: .rotation)
        try container.encode(isLocked, forKey: .isLocked)
        try container.encode(zIndex, forKey: .zIndex)
        try container.encode(CodableColor(strokeColor), forKey: .strokeColor)
        try container.encode(strokeWidth, forKey: .strokeWidth)
        try container.encode(strokeStyle, forKey: .strokeStyle)
    }

    // MARK: - Copy

    public func copied(newId: UUID, zIndex: Int, offset: CGPoint) -> PencilObject {
        let offsetPoints = points.map { CGPoint(x: $0.x + offset.x, y: $0.y + offset.y) }
        return PencilObject(
            id: newId,
            points: offsetPoints,
            strokeColor: strokeColor,
            strokeWidth: strokeWidth,
            strokeStyle: strokeStyle,
            rotation: rotation,
            isLocked: false,
            zIndex: zIndex
        )
    }

    // MARK: - CanvasObject Methods

    public func contains(_ point: CGPoint) -> Bool {
        let localPoint = rotation != 0 ? transformToLocal(point) : point
        let threshold = max(strokeWidth / 2 + 4, 8)
        return minimumDistanceToStroke(localPoint) < threshold
    }

    public func boundingBox() -> CGRect {
        let pad = strokeWidth / 2
        return pointsBounds.insetBy(dx: -pad, dy: -pad)
    }

    /// Marquee intersection: checks if any stroke segment intersects the rect.
    public func intersectsRect(_ rect: CGRect) -> Bool {
        guard rect.intersects(boundingBox()) else { return false }
        guard points.count >= 2 else {
            return points.first.map { rect.contains($0) } ?? false
        }
        // Check each consecutive pair
        for i in 0..<(points.count - 1) {
            if segmentIntersectsRect(p0: points[i], p1: points[i + 1], rect: rect) {
                return true
            }
        }
        return false
    }

    public func hitTest(_ point: CGPoint, threshold: CGFloat) -> HitTestResult? {
        let localPoint = rotation != 0 ? transformToLocal(point) : point
        if minimumDistanceToStroke(localPoint) <= threshold {
            return .body
        }
        return nil
    }
}

// MARK: - Geometry Helpers

private extension PencilObject {

    /// Minimum distance from `point` to any segment of the stroke polyline.
    func minimumDistanceToStroke(_ point: CGPoint) -> CGFloat {
        guard points.count >= 2 else {
            return points.first.map { hypot($0.x - point.x, $0.y - point.y) } ?? .infinity
        }
        var minDist = CGFloat.infinity
        for i in 0..<(points.count - 1) {
            let d = distanceToSegment(point: point, p0: points[i], p1: points[i + 1])
            if d < minDist { minDist = d }
        }
        return minDist
    }

    /// Point-to-segment distance.
    func distanceToSegment(point: CGPoint, p0: CGPoint, p1: CGPoint) -> CGFloat {
        let dx = p1.x - p0.x
        let dy = p1.y - p0.y
        let lenSq = dx * dx + dy * dy
        if lenSq == 0 {
            return hypot(point.x - p0.x, point.y - p0.y)
        }
        let t = max(0, min(1, ((point.x - p0.x) * dx + (point.y - p0.y) * dy) / lenSq))
        return hypot(point.x - (p0.x + t * dx), point.y - (p0.y + t * dy))
    }

    /// Cohen-Sutherland test: does segment (p0,p1) intersect the rect?
    func segmentIntersectsRect(p0: CGPoint, p1: CGPoint, rect: CGRect) -> Bool {
        if rect.contains(p0) || rect.contains(p1) { return true }
        var tMin: CGFloat = 0
        var tMax: CGFloat = 1
        let dx = p1.x - p0.x
        let dy = p1.y - p0.y

        func clip(p: CGFloat, q: CGFloat) -> Bool {
            if p == 0 { return q >= 0 }
            let t = q / p
            if p < 0 {
                if t > tMax { return false }
                if t > tMin { tMin = t }
            } else {
                if t < tMin { return false }
                if t < tMax { tMax = t }
            }
            return true
        }

        guard clip(p: -dx, q: p0.x - rect.minX) else { return false }
        guard clip(p:  dx, q: rect.maxX - p0.x) else { return false }
        guard clip(p: -dy, q: p0.y - rect.minY) else { return false }
        guard clip(p:  dy, q: rect.maxY - p0.y) else { return false }
        return tMin <= tMax
    }
}

// MARK: - Catmull-Rom Path Builder

extension PencilObject {

    /// The bounding box origin used as the local-coordinate offset.
    /// All `localPath()` coordinates are relative to this point.
    public var localOrigin: CGPoint { pointsBounds.origin }

    /// Build a smooth path in local coordinates (origin at bounding box top-left).
    /// Use this for rendering so that `.rotationEffect` rotates around the visual center.
    public func localSmoothPath() -> Path {
        let origin = pointsBounds.origin
        let offsetPoints = points.map { CGPoint(x: $0.x - origin.x, y: $0.y - origin.y) }
        return PencilObject.buildSmoothPath(from: offsetPoints)
    }

    /// Build a smooth SwiftUI Path using Catmull-Rom spline interpolation.
    /// Falls back to polyline when there are fewer than 4 points.
    public func smoothPath() -> Path {
        return PencilObject.buildSmoothPath(from: points)
    }

    /// Internal path builder over an arbitrary point list.
    private static func buildSmoothPath(from pts: [CGPoint]) -> Path {
        guard pts.count >= 2 else {
            var p = Path()
            if let first = pts.first { p.move(to: first) }
            return p
        }

        var path = Path()

        if pts.count == 2 {
            path.move(to: pts[0])
            path.addLine(to: pts[1])
            return path
        }

        path.move(to: pts[0])

        // Catmull-Rom → cubic Bezier conversion
        // For each interior segment (i → i+1), use the surrounding control points.
        for i in 0..<(pts.count - 1) {
            let p0 = pts[max(i - 1, 0)]
            let p1 = pts[i]
            let p2 = pts[i + 1]
            let p3 = pts[min(i + 2, pts.count - 1)]

            // Tangent scale factor (Catmull-Rom alpha = 0.5)
            let alpha: CGFloat = 1.0 / 6.0

            let cp1 = CGPoint(
                x: p1.x + alpha * (p2.x - p0.x),
                y: p1.y + alpha * (p2.y - p0.y)
            )
            let cp2 = CGPoint(
                x: p2.x - alpha * (p3.x - p1.x),
                y: p2.y - alpha * (p3.y - p1.y)
            )

            path.addCurve(to: p2, control1: cp1, control2: cp2)
        }

        return path
    }
}
