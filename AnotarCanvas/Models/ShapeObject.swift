//
//  ShapeObject.swift
//  AnotarCanvas
//

import SwiftUI
#if canImport(SVGPath)
import SVGPath
#endif

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
    public var svgPath: String            // The geometry (SVG path string)
    public var toolId: String             // "rectangle", "oval", etc. for deserialization
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
        svgPath: String,
        toolId: String,
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
        self.svgPath = svgPath
        self.toolId = toolId
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
        svgPath: String,
        toolId: String,
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
        self.svgPath = svgPath
        self.toolId = toolId
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
        case svgPath, toolId, autoResizeHeight
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
        svgPath = try container.decode(String.self, forKey: .svgPath)
        toolId = try container.decode(String.self, forKey: .toolId)
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
        try container.encode(svgPath, forKey: .svgPath)
        try container.encode(toolId, forKey: .toolId)
        try container.encode(autoResizeHeight, forKey: .autoResizeHeight)
    }

    // MARK: - Path Helper

    /// Cache key for cgPath: encodes both the SVG path string and the target rect.
    private final class ShapePathCacheKey: NSObject {
        public let key: String
        public init(svgPath: String, rect: CGRect) {
            self.key = "\(svgPath)|\(rect.minX),\(rect.minY),\(rect.width),\(rect.height)"
        }
        override var hash: Int { key.hashValue }
        override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? ShapePathCacheKey else { return false }
            return key == other.key
        }
    }

    private let cgPathCache = NSCache<ShapePathCacheKey, CGPath>()

    /// Returns a CGPath scaled to fill `rect` exactly (stretch, not letterbox).
    /// Results are cached in a static NSCache to avoid re-parsing the SVG string
    /// on every hit-test or render call.
    public func cgPath(in rect: CGRect) -> CGPath {
        let cacheKey = ShapePathCacheKey(svgPath: svgPath, rect: rect)
        if let cached = cgPathCache.object(forKey: cacheKey) {
            return cached
        }

        #if canImport(SVGPath)
        // Use invertYAxis: false so SVG Y-down coordinates match SwiftUI/screen space.
        guard let parsed = try? SVGPath(string: svgPath, with: .init(invertYAxis: false)) else {
            return CGPath(rect: rect, transform: nil)
        }
        let rawPath = CGPath.from(parsed)
        let unitBounds = rawPath.boundingBoxOfPath
        guard unitBounds.width > 0 && unitBounds.height > 0 else {
            return CGPath(rect: rect, transform: nil)
        }
        var transform = CGAffineTransform(translationX: rect.minX, y: rect.minY)
            .scaledBy(x: rect.width / unitBounds.width, y: rect.height / unitBounds.height)
            .translatedBy(x: -unitBounds.minX, y: -unitBounds.minY)
        let result = rawPath.copy(using: &transform) ?? CGPath(rect: rect, transform: nil)
        cgPathCache.setObject(result, forKey: cacheKey)
        return result
        #else
        // Fallback without SVGPath module
        return CGPath(rect: rect, transform: nil)
        #endif
    }

    /// Returns a SwiftUI Path scaled to fill `rect` exactly.
    public func path(in rect: CGRect) -> Path {
        Path(cgPath(in: rect))
    }

    // MARK: - Copy

    public func copied(newId: UUID, zIndex: Int, offset: CGPoint) -> ShapeObject {
        ShapeObject(
            id: newId,
            position: CGPoint(x: position.x + offset.x, y: position.y + offset.y),
            size: size,
            svgPath: svgPath,
            toolId: toolId,
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
        return cgPath(in: boundingBox()).contains(localPoint)
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
        let path = cgPath(in: bounds)
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
