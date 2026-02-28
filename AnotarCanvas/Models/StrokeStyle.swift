//
//  StrokeStyle.swift
//  AnotarCanvas
//
//  Created by Claude on 2/18/26.
//

import SwiftUI

/// Defines the style of a stroke (solid, dashed, dotted)
public enum StrokeStyleType: Codable, Hashable {
    case solid
    case dashed(pattern: [CGFloat])
    case dotted

    /// Returns the dash pattern for this stroke style.
    /// For fixed-pattern styles (.solid, .dotted), use `dashPattern(for:)` instead
    /// so spacing scales with line width.
    public var dashPattern: [CGFloat] {
        switch self {
        case .solid:
            return []
        case .dashed(let pattern):
            return pattern
        case .dotted:
            return [0, 6]   // fallback; callers should use dashPattern(for:lineWidth:)
        }
    }

    /// Returns a dash pattern scaled to the given line width so gaps remain
    /// visually consistent regardless of stroke thickness.
    ///
    /// With round lineCap each dash visually extends by lineWidth/2 on each end,
    /// so the stored gap must be `desired_visual_gap + lineWidth` to compensate.
    public func dashPattern(for lineWidth: CGFloat) -> [CGFloat] {
        switch self {
        case .solid:
            return []
        case .dashed:
            // Target: visual dash ≈ 3× lineWidth, visual gap ≈ 2× lineWidth.
            // Stored gap = visual_gap + lineWidth (cap overhang correction).
            return [lineWidth * 3.0, lineWidth * 3.0]
        case .dotted:
            // Dot = 0-length dash; round cap renders it as a circle.
            // Stored gap = desired_visual_gap + lineWidth.
            return [0, lineWidth * 3.0]
        }
    }

    /// Default dashed pattern
    public static var defaultDashed: StrokeStyleType {
        .dashed(pattern: [8, 4])
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case type
        case pattern
    }

    private enum StyleType: String, Codable {
        case solid
        case dashed
        case dotted
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(StyleType.self, forKey: .type)

        switch type {
        case .solid:
            self = .solid
        case .dashed:
            let pattern = try container.decode([CGFloat].self, forKey: .pattern)
            self = .dashed(pattern: pattern)
        case .dotted:
            self = .dotted
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .solid:
            try container.encode(StyleType.solid, forKey: .type)
        case .dashed(let pattern):
            try container.encode(StyleType.dashed, forKey: .type)
            try container.encode(pattern, forKey: .pattern)
        case .dotted:
            try container.encode(StyleType.dotted, forKey: .type)
        }
    }
}

// MARK: - SwiftUI StrokeStyle Conversion

public extension StrokeStyleType {
    /// Creates a SwiftUI StrokeStyle with the given line width.
    /// Dash and gap lengths scale with lineWidth so the pattern looks consistent
    /// at any stroke thickness.
    public func swiftUIStrokeStyle(lineWidth: CGFloat, lineCap: CGLineCap = .round, lineJoin: CGLineJoin = .round) -> SwiftUI.StrokeStyle {
        // Dotted strokes always use round caps so 0-length dashes become circles.
        let cap: CGLineCap = (self == .dotted) ? .round : lineCap
        return SwiftUI.StrokeStyle(
            lineWidth: lineWidth,
            lineCap: cap,
            lineJoin: lineJoin,
            dash: dashPattern(for: lineWidth)
        )
    }
}
