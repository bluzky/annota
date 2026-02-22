//
//  ShapeObject.swift
//  texttool
//

import SwiftUI
import SVGPath

public struct ShapeObject: CanvasObject, TextContentObject, StrokableObject, FillableObject, CopyableCanvasObject {
    // MARK: - CanvasObject
    public let id: UUID
    public var position: CGPoint
    public var size: CGSize
    public var rotation: CGFloat = 0
    public var isLocked: Bool = false
    public var zIndex: Int = 0

    // MARK: - StrokableObject
    public var strokeColor: Color
    public var strokeWidth: CGFloat = 2
    public var strokeStyle: StrokeStyleType = .solid

    // MARK: - FillableObject
    public var fillColor: Color
    public var fillOpacity: CGFloat = 0.1

    // MARK: - TextContentObject
    public var text: String = ""
    public var textAttributes: TextAttributes = .default
    public var isEditing: Bool = false

    // MARK: - Shape-specific
    public var preset: ShapePreset
    public var autoResizeHeight: Bool = false

    // MARK: - Backward Compatibility

    /// Convenience accessor for color (maps to strokeColor/fillColor)
    public var color: Color {
        get { strokeColor }
        set {
            strokeColor = newValue
            fillColor = newValue
        }
    }

    // MARK: - Init

    public init(
        id: UUID = UUID(),
        position: CGPoint,
        size: CGSize,
        preset: ShapePreset = .rectangle,
        color: Color = .black,
        strokeWidth: CGFloat = 2,
        strokeStyle: StrokeStyleType = .solid,
        fillOpacity: CGFloat = 0.1,
        text: String = "",
        isEditing: Bool = false,
        autoResizeHeight: Bool = false,
        rotation: CGFloat = 0,
        isLocked: Bool = false,
        zIndex: Int = 0
    ) {
        self.id = id
        self.position = position
        self.size = size
        self.preset = preset
        self.strokeColor = color
        self.fillColor = color
        self.strokeWidth = strokeWidth
        self.strokeStyle = strokeStyle
        self.fillOpacity = fillOpacity
        self.text = text
        self.isEditing = isEditing
        self.autoResizeHeight = autoResizeHeight
        self.rotation = rotation
        self.isLocked = isLocked
        self.zIndex = zIndex
    }

    /// Memberwise initializer that accepts strokeColor and fillColor independently.
    /// Used by copied(newId:zIndex:offset:) to preserve independent fill/stroke colors.
    public init(
        id: UUID,
        position: CGPoint,
        size: CGSize,
        preset: ShapePreset,
        strokeColor: Color,
        fillColor: Color,
        strokeWidth: CGFloat,
        strokeStyle: StrokeStyleType,
        fillOpacity: CGFloat,
        text: String,
        textAttributes: TextAttributes,
        isEditing: Bool,
        autoResizeHeight: Bool,
        rotation: CGFloat,
        isLocked: Bool,
        zIndex: Int
    ) {
        self.id = id
        self.position = position
        self.size = size
        self.preset = preset
        self.strokeColor = strokeColor
        self.fillColor = fillColor
        self.strokeWidth = strokeWidth
        self.strokeStyle = strokeStyle
        self.fillOpacity = fillOpacity
        self.text = text
        self.textAttributes = textAttributes
        self.isEditing = isEditing
        self.autoResizeHeight = autoResizeHeight
        self.rotation = rotation
        self.isLocked = isLocked
        self.zIndex = zIndex
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case id, position, size, rotation, isLocked, zIndex
        case strokeColor, strokeWidth, strokeStyle
        case fillColor, fillOpacity
        case text, textAttributes
        case preset, autoResizeHeight
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        position = try container.decode(CGPoint.self, forKey: .position)
        size = try container.decode(CGSize.self, forKey: .size)
        rotation = try container.decodeIfPresent(CGFloat.self, forKey: .rotation) ?? 0
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        zIndex = try container.decodeIfPresent(Int.self, forKey: .zIndex) ?? 0
        let codableStroke = try container.decode(CodableColor.self, forKey: .strokeColor)
        strokeColor = codableStroke.color
        strokeWidth = try container.decodeIfPresent(CGFloat.self, forKey: .strokeWidth) ?? 2
        strokeStyle = try container.decodeIfPresent(StrokeStyleType.self, forKey: .strokeStyle) ?? .solid
        let codableFill = try container.decode(CodableColor.self, forKey: .fillColor)
        fillColor = codableFill.color
        fillOpacity = try container.decodeIfPresent(CGFloat.self, forKey: .fillOpacity) ?? 0.1
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        textAttributes = try container.decodeIfPresent(TextAttributes.self, forKey: .textAttributes) ?? .default
        preset = try container.decode(ShapePreset.self, forKey: .preset)
        autoResizeHeight = try container.decodeIfPresent(Bool.self, forKey: .autoResizeHeight) ?? false
        isEditing = false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(position, forKey: .position)
        try container.encode(size, forKey: .size)
        try container.encode(rotation, forKey: .rotation)
        try container.encode(isLocked, forKey: .isLocked)
        try container.encode(zIndex, forKey: .zIndex)
        try container.encode(CodableColor(strokeColor), forKey: .strokeColor)
        try container.encode(strokeWidth, forKey: .strokeWidth)
        try container.encode(strokeStyle, forKey: .strokeStyle)
        try container.encode(CodableColor(fillColor), forKey: .fillColor)
        try container.encode(fillOpacity, forKey: .fillOpacity)
        try container.encode(text, forKey: .text)
        try container.encode(textAttributes, forKey: .textAttributes)
        try container.encode(preset, forKey: .preset)
        try container.encode(autoResizeHeight, forKey: .autoResizeHeight)
    }

    // MARK: - Copy

    public func copied(newId: UUID, zIndex: Int, offset: CGPoint) -> ShapeObject {
        ShapeObject(
            id: newId,
            position: CGPoint(x: position.x + offset.x, y: position.y + offset.y),
            size: size,
            preset: preset,
            strokeColor: strokeColor,
            fillColor: fillColor,
            strokeWidth: strokeWidth,
            strokeStyle: strokeStyle,
            fillOpacity: fillOpacity,
            text: text,
            textAttributes: textAttributes,
            isEditing: false,
            autoResizeHeight: autoResizeHeight,
            rotation: rotation,
            isLocked: false,
            zIndex: zIndex
        )
    }

    // MARK: - CanvasObject

    public func contains(_ point: CGPoint) -> Bool {
        let localPoint = rotation != 0 ? transformToLocal(point) : point
        return preset.cgPath(in: boundingBox()).contains(localPoint)
    }

    public func boundingBox() -> CGRect {
        CGRect(origin: position, size: size)
    }

    public func hitTest(_ point: CGPoint, threshold: CGFloat) -> HitTestResult? {
        let localPoint = rotation != 0 ? transformToLocal(point) : point
        let bounds = boundingBox()

        // Quick-reject: outside expanded bounding box
        guard bounds.insetBy(dx: -threshold, dy: -threshold).contains(localPoint) else {
            return nil
        }

        // Corners: always the four bounding-box corners (resize handles are rectangular)
        if let corner = hitTestCorner(point: localPoint, bounds: bounds, threshold: threshold) {
            return .corner(corner)
        }

        // Edge: stroke the CGPath — shape-agnostic, handles curves and polygons
        let path = preset.cgPath(in: bounds)
        let strokedPath = path.copy(
            strokingWithWidth: threshold * 2,
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 1
        )
        if strokedPath.contains(localPoint) {
            return .edge(edgeForPoint(localPoint, in: bounds))
        }

        // Body: interior of the shape path
        if path.contains(localPoint) {
            return .body
        }

        return nil
    }
}

// MARK: - Private Helpers

private extension ShapeObject {
    func hitTestCorner(point: CGPoint, bounds: CGRect, threshold: CGFloat) -> Corner? {
        let corners: [(Corner, CGPoint)] = [
            (.topLeft,     CGPoint(x: bounds.minX, y: bounds.minY)),
            (.topRight,    CGPoint(x: bounds.maxX, y: bounds.minY)),
            (.bottomLeft,  CGPoint(x: bounds.minX, y: bounds.maxY)),
            (.bottomRight, CGPoint(x: bounds.maxX, y: bounds.maxY)),
        ]
        for (corner, cp) in corners {
            if hypot(point.x - cp.x, point.y - cp.y) <= threshold { return corner }
        }
        return nil
    }

    /// Classify a point near the shape boundary into the nearest cardinal edge.
    /// Normalises by half-extents so aspect ratio doesn't bias the result.
    func edgeForPoint(_ point: CGPoint, in bounds: CGRect) -> Edge {
        let halfW = bounds.width / 2
        let halfH = bounds.height / 2
        // Guard against zero-size bounds to avoid division by zero
        guard halfW > 0, halfH > 0 else { return .right }
        let dx = point.x - bounds.midX
        let dy = point.y - bounds.midY
        let nx = dx / halfW
        let ny = dy / halfH
        if abs(nx) >= abs(ny) {
            return nx >= 0 ? .right : .left
        } else {
            return ny >= 0 ? .bottom : .top
        }
    }
}
