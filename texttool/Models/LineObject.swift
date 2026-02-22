//
//  LineObject.swift
//  texttool
//

import SwiftUI

/// Arrowhead styles for line endpoints
enum ArrowHead: String, Codable, Hashable, CaseIterable {
    case none
    case open       // V shape
    case filled     // Filled triangle
    case circle     // Circle endpoint
    case diamond    // Diamond shape
}

/// A single struct for both lines and arrows.
/// A plain line has `.none` arrowheads; an arrow typically has `endArrowHead = .filled`.
struct LineObject: CanvasObject, StrokableObject, CopyableCanvasObject {
    // MARK: - CanvasObject Properties
    let id: UUID
    var rotation: CGFloat = 0
    var isLocked: Bool = false
    var zIndex: Int = 0

    // MARK: - Control Points
    var startPoint: CGPoint
    var endPoint: CGPoint

    // MARK: - StrokableObject Properties
    var strokeColor: Color = .black
    var strokeWidth: CGFloat = 2
    var strokeStyle: StrokeStyleType = .solid

    // MARK: - Arrowhead Properties
    var startArrowHead: ArrowHead = .none
    var endArrowHead: ArrowHead = .none

    // MARK: - Optional Label
    var label: String = ""
    var labelAttributes: TextAttributes = .default
    var isEditingLabel: Bool = false

    // MARK: - Computed Properties

    var usesControlPoints: Bool { true }

    /// Whether this line object acts as an arrow (has at least one arrowhead)
    var isArrow: Bool {
        startArrowHead != .none || endArrowHead != .none
    }

    /// Position is the top-left corner of the bounding box
    var position: CGPoint {
        get {
            CGPoint(
                x: min(startPoint.x, endPoint.x),
                y: min(startPoint.y, endPoint.y)
            )
        }
        set {
            let dx = newValue.x - position.x
            let dy = newValue.y - position.y
            startPoint.x += dx
            startPoint.y += dy
            endPoint.x += dx
            endPoint.y += dy
        }
    }

    /// Size is the bounding box of the two control points
    var size: CGSize {
        get {
            CGSize(
                width: abs(endPoint.x - startPoint.x),
                height: abs(endPoint.y - startPoint.y)
            )
        }
        set {
            let currentSize = size
            let origin = position

            // For axis-aligned lines (horizontal or vertical), only scale the non-degenerate axis.
            // Scaling a zero-width or zero-height axis would divide by zero and leave the line unchanged.
            if currentSize.width == 0 {
                // Vertical line: only scale height
                guard currentSize.height > 0 else { return }
                let scaleY = newValue.height / currentSize.height
                startPoint = CGPoint(x: origin.x, y: origin.y + (startPoint.y - origin.y) * scaleY)
                endPoint   = CGPoint(x: origin.x, y: origin.y + (endPoint.y   - origin.y) * scaleY)
                return
            }
            if currentSize.height == 0 {
                // Horizontal line: only scale width
                guard currentSize.width > 0 else { return }
                let scaleX = newValue.width / currentSize.width
                startPoint = CGPoint(x: origin.x + (startPoint.x - origin.x) * scaleX, y: origin.y)
                endPoint   = CGPoint(x: origin.x + (endPoint.x   - origin.x) * scaleX, y: origin.y)
                return
            }

            let scaleX = newValue.width / currentSize.width
            let scaleY = newValue.height / currentSize.height
            startPoint = CGPoint(
                x: origin.x + (startPoint.x - origin.x) * scaleX,
                y: origin.y + (startPoint.y - origin.y) * scaleY
            )
            endPoint = CGPoint(
                x: origin.x + (endPoint.x - origin.x) * scaleX,
                y: origin.y + (endPoint.y - origin.y) * scaleY
            )
        }
    }

    /// The midpoint of the line segment
    var midPoint: CGPoint {
        CGPoint(
            x: (startPoint.x + endPoint.x) / 2,
            y: (startPoint.y + endPoint.y) / 2
        )
    }

    /// The length of the line segment
    var length: CGFloat {
        hypot(endPoint.x - startPoint.x, endPoint.y - startPoint.y)
    }

    /// The angle of the line in radians
    var angle: CGFloat {
        atan2(endPoint.y - startPoint.y, endPoint.x - startPoint.x)
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        startPoint: CGPoint,
        endPoint: CGPoint,
        strokeColor: Color = .black,
        strokeWidth: CGFloat = 2,
        strokeStyle: StrokeStyleType = .solid,
        startArrowHead: ArrowHead = .none,
        endArrowHead: ArrowHead = .none,
        label: String = "",
        rotation: CGFloat = 0,
        isLocked: Bool = false,
        zIndex: Int = 0
    ) {
        self.id = id
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
        self.strokeStyle = strokeStyle
        self.startArrowHead = startArrowHead
        self.endArrowHead = endArrowHead
        self.label = label
        self.rotation = rotation
        self.isLocked = isLocked
        self.zIndex = zIndex
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case id, startPoint, endPoint, rotation, isLocked, zIndex
        case strokeColor, strokeWidth, strokeStyle
        case startArrowHead, endArrowHead
        case label, labelAttributes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        startPoint = try container.decode(CGPoint.self, forKey: .startPoint)
        endPoint = try container.decode(CGPoint.self, forKey: .endPoint)
        rotation = try container.decodeIfPresent(CGFloat.self, forKey: .rotation) ?? 0
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        zIndex = try container.decodeIfPresent(Int.self, forKey: .zIndex) ?? 0
        let codableStroke = try container.decode(CodableColor.self, forKey: .strokeColor)
        strokeColor = codableStroke.color
        strokeWidth = try container.decodeIfPresent(CGFloat.self, forKey: .strokeWidth) ?? 2
        strokeStyle = try container.decodeIfPresent(StrokeStyleType.self, forKey: .strokeStyle) ?? .solid
        startArrowHead = try container.decodeIfPresent(ArrowHead.self, forKey: .startArrowHead) ?? .none
        endArrowHead = try container.decodeIfPresent(ArrowHead.self, forKey: .endArrowHead) ?? .none
        label = try container.decodeIfPresent(String.self, forKey: .label) ?? ""
        labelAttributes = try container.decodeIfPresent(TextAttributes.self, forKey: .labelAttributes) ?? .default
        isEditingLabel = false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(startPoint, forKey: .startPoint)
        try container.encode(endPoint, forKey: .endPoint)
        try container.encode(rotation, forKey: .rotation)
        try container.encode(isLocked, forKey: .isLocked)
        try container.encode(zIndex, forKey: .zIndex)
        try container.encode(CodableColor(strokeColor), forKey: .strokeColor)
        try container.encode(strokeWidth, forKey: .strokeWidth)
        try container.encode(strokeStyle, forKey: .strokeStyle)
        try container.encode(startArrowHead, forKey: .startArrowHead)
        try container.encode(endArrowHead, forKey: .endArrowHead)
        try container.encode(label, forKey: .label)
        try container.encode(labelAttributes, forKey: .labelAttributes)
    }

    // MARK: - Copy

    func copied(newId: UUID, zIndex: Int, offset: CGPoint) -> LineObject {
        var copy = LineObject(
            id: newId,
            startPoint: CGPoint(x: startPoint.x + offset.x, y: startPoint.y + offset.y),
            endPoint: CGPoint(x: endPoint.x + offset.x, y: endPoint.y + offset.y),
            strokeColor: strokeColor,
            strokeWidth: strokeWidth,
            strokeStyle: strokeStyle,
            startArrowHead: startArrowHead,
            endArrowHead: endArrowHead,
            label: label,
            rotation: rotation,
            isLocked: false,
            zIndex: zIndex
        )
        copy.labelAttributes = labelAttributes
        return copy
    }

    // MARK: - CanvasObject Methods

    func contains(_ point: CGPoint) -> Bool {
        let localPoint = rotation != 0 ? transformToLocal(point) : point

        // Check label area
        if !label.isEmpty && labelBounds().contains(localPoint) {
            return true
        }

        // Check line proximity
        return distanceToLineSegment(localPoint) < max(strokeWidth / 2 + 4, 8)
    }

    func boundingBox() -> CGRect {
        CGRect(origin: position, size: size)
    }

    func hitTest(_ point: CGPoint, threshold: CGFloat) -> HitTestResult? {
        let localPoint = rotation != 0 ? transformToLocal(point) : point

        // Check control points first (endpoints for reshaping)
        if hypot(localPoint.x - startPoint.x, localPoint.y - startPoint.y) <= threshold {
            return .controlPoint(index: 0)
        }
        if hypot(localPoint.x - endPoint.x, localPoint.y - endPoint.y) <= threshold {
            return .controlPoint(index: 1)
        }

        // Check label area
        if !label.isEmpty && labelBounds().contains(localPoint) {
            return .label
        }

        // Check line proximity using point-to-line-segment distance
        if distanceToLineSegment(localPoint) <= threshold {
            return .body
        }

        return nil
    }
}

// MARK: - Geometry Helpers

private extension LineObject {
    /// Compute the shortest distance from a point to the line segment (startPoint, endPoint)
    func distanceToLineSegment(_ point: CGPoint) -> CGFloat {
        let dx = endPoint.x - startPoint.x
        let dy = endPoint.y - startPoint.y
        let lengthSq = dx * dx + dy * dy

        // Degenerate case: start == end
        if lengthSq == 0 {
            return hypot(point.x - startPoint.x, point.y - startPoint.y)
        }

        // Project point onto the line, clamping t to [0, 1]
        let t = max(0, min(1, ((point.x - startPoint.x) * dx + (point.y - startPoint.y) * dy) / lengthSq))

        // Closest point on the segment
        let projX = startPoint.x + t * dx
        let projY = startPoint.y + t * dy

        return hypot(point.x - projX, point.y - projY)
    }

    /// Bounding rect for the label, centered at the midpoint
    func labelBounds() -> CGRect {
        let labelSize = estimateLabelSize()
        return CGRect(
            x: midPoint.x - labelSize.width / 2,
            y: midPoint.y - labelSize.height / 2,
            width: labelSize.width,
            height: labelSize.height
        )
    }

    /// Estimate label size based on text and attributes
    func estimateLabelSize() -> CGSize {
        guard !label.isEmpty else { return .zero }
        let font = labelAttributes.nsFont
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = (label as NSString).boundingRect(
            with: CGSize(width: 200, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: attrs
        ).size
        return CGSize(width: textSize.width + 12, height: textSize.height + 8)
    }
}
