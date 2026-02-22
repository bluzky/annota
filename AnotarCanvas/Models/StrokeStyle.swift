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

    /// Returns the dash pattern for this stroke style
    public var dashPattern: [CGFloat] {
        switch self {
        case .solid:
            return []
        case .dashed(let pattern):
            return pattern
        case .dotted:
            return [2, 4]
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
    /// Creates a SwiftUI StrokeStyle with the given line width
    public func swiftUIStrokeStyle(lineWidth: CGFloat, lineCap: CGLineCap = .round, lineJoin: CGLineJoin = .round) -> SwiftUI.StrokeStyle {
        SwiftUI.StrokeStyle(
            lineWidth: lineWidth,
            lineCap: lineCap,
            lineJoin: lineJoin,
            dash: dashPattern
        )
    }
}
