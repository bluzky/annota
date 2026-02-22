//
//  ShapePreset.swift
//  texttool
//

import SwiftUI
import SVGPath

/// A value type describing a shape via a normalized SVG path.
/// Paths are defined in a 0–100 unit coordinate space; SVGPath scales
/// them to fit the object's actual bounding rect at render/hit-test time.
public struct ShapePreset: Codable, Hashable, Sendable {
    public let name: String
    public let svgPath: String
    public let sfSymbol: String

    public init(name: String, svgPath: String, sfSymbol: String = "square.on.square") {
        self.name = name
        self.svgPath = svgPath
        self.sfSymbol = sfSymbol
    }
}

// MARK: - Built-in Presets

public extension ShapePreset {
    public static let rectangle = ShapePreset(
        name: "Rectangle",
        svgPath: "M 0 0 L 100 0 L 100 100 L 0 100 Z",
        sfSymbol: "rectangle"
    )

    public static let oval = ShapePreset(
        name: "Oval",
        svgPath: """
        M 50 0
        C 77.6 0 100 22.4 100 50
        C 100 77.6 77.6 100 50 100
        C 22.4 100 0 77.6 0 50
        C 0 22.4 22.4 0 50 0 Z
        """,
        sfSymbol: "circle"
    )

    /// Corner radius is a value in the 0–100 unit space (e.g. 12 ≈ 12% of the shape).
    public static func roundedRectangle(cornerRadius: CGFloat) -> ShapePreset {
        let r = min(max(cornerRadius, 0), 50)
        let svgPath = """
        M \(r) 0
        L \(100 - r) 0
        Q 100 0 100 \(r)
        L 100 \(100 - r)
        Q 100 100 \(100 - r) 100
        L \(r) 100
        Q 0 100 0 \(100 - r)
        L 0 \(r)
        Q 0 0 \(r) 0 Z
        """
        return ShapePreset(name: "Rounded Rectangle", svgPath: svgPath, sfSymbol: "rectangle.roundedtop")
    }

    public static let triangle = ShapePreset(
        name: "Triangle",
        svgPath: "M 50 0 L 100 100 L 0 100 Z",
        sfSymbol: "triangle"
    )

    public static let diamond = ShapePreset(
        name: "Diamond",
        svgPath: "M 50 0 L 100 50 L 50 100 L 0 50 Z",
        sfSymbol: "diamond"
    )

    public static let arrow = ShapePreset(
        name: "Arrow",
        svgPath: "M 0 30 L 60 30 L 60 0 L 100 50 L 60 100 L 60 70 L 0 70 Z",
        sfSymbol: "arrow.right"
    )

    public static let star = ShapePreset(
        name: "Star",
        svgPath: """
        M 50 0 L 61 35 L 98 35 L 68 57 L 79 91
        L 50 70 L 21 91 L 32 57 L 2 35 L 39 35 Z
        """,
        sfSymbol: "star"
    )

    /// All built-in presets in display order.
    public static let builtIn: [ShapePreset] = [
        .rectangle, .oval, .roundedRectangle(cornerRadius: 12),
        .triangle, .diamond, .arrow, .star
    ]
}

// MARK: - Rendering Helpers

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

public extension ShapePreset {
    /// Returns a CGPath scaled to fill `rect` exactly (stretch, not letterbox).
    /// Results are cached in a static NSCache to avoid re-parsing the SVG string
    /// on every hit-test or render call.
    public func cgPath(in rect: CGRect) -> CGPath {
        let cacheKey = ShapePathCacheKey(svgPath: svgPath, rect: rect)
        if let cached = cgPathCache.object(forKey: cacheKey) {
            return cached
        }

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
    }

    /// Returns a SwiftUI Path scaled to fill `rect` exactly.
    public func path(in rect: CGRect) -> Path {
        Path(cgPath(in: rect))
    }

}
