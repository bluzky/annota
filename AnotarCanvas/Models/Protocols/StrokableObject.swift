//
//  StrokableObject.swift
//  texttool
//
//  Created by Claude on 2/18/26.
//

import SwiftUI

/// Protocol for canvas objects that can have a stroke/border
public protocol StrokableObject: CanvasObject {
    /// The color of the stroke
    var strokeColor: Color { get set }

    /// The width of the stroke in points
    var strokeWidth: CGFloat { get set }

    /// The style of the stroke (solid, dashed, dotted)
    var strokeStyle: StrokeStyleType { get set }
}

// MARK: - Default Implementations

public extension StrokableObject {
    /// Returns true if this object has a visible stroke
    public var hasStroke: Bool {
        strokeWidth > 0
    }

    /// Creates a SwiftUI StrokeStyle from the current stroke properties
    public var swiftUIStrokeStyle: SwiftUI.StrokeStyle {
        strokeStyle.swiftUIStrokeStyle(lineWidth: strokeWidth)
    }

    /// The total inset needed to account for stroke width
    /// (stroke is centered on the edge, so half extends outward)
    public var strokeInset: CGFloat {
        strokeWidth / 2
    }

    /// Returns the bounds expanded to include the stroke
    public func strokeBounds() -> CGRect {
        boundingBox().insetBy(dx: -strokeInset, dy: -strokeInset)
    }
}

// MARK: - Default Values

public extension StrokableObject {
    /// Default stroke color
    public static var defaultStrokeColor: Color { .black }

    /// Default stroke width
    public static var defaultStrokeWidth: CGFloat { 2.0 }

    /// Default stroke style
    public static var defaultStrokeStyle: StrokeStyleType { .solid }
}
