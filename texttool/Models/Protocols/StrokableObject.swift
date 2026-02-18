//
//  StrokableObject.swift
//  texttool
//
//  Created by Claude on 2/18/26.
//

import SwiftUI

/// Protocol for canvas objects that can have a stroke/border
protocol StrokableObject: CanvasObject {
    /// The color of the stroke
    var strokeColor: Color { get set }

    /// The width of the stroke in points
    var strokeWidth: CGFloat { get set }

    /// The style of the stroke (solid, dashed, dotted)
    var strokeStyle: StrokeStyleType { get set }
}

// MARK: - Default Implementations

extension StrokableObject {
    /// Returns true if this object has a visible stroke
    var hasStroke: Bool {
        strokeWidth > 0
    }

    /// Creates a SwiftUI StrokeStyle from the current stroke properties
    var swiftUIStrokeStyle: SwiftUI.StrokeStyle {
        strokeStyle.swiftUIStrokeStyle(lineWidth: strokeWidth)
    }

    /// The total inset needed to account for stroke width
    /// (stroke is centered on the edge, so half extends outward)
    var strokeInset: CGFloat {
        strokeWidth / 2
    }

    /// Returns the bounds expanded to include the stroke
    func strokeBounds() -> CGRect {
        boundingBox().insetBy(dx: -strokeInset, dy: -strokeInset)
    }
}

// MARK: - Default Values

extension StrokableObject {
    /// Default stroke color
    static var defaultStrokeColor: Color { .black }

    /// Default stroke width
    static var defaultStrokeWidth: CGFloat { 2.0 }

    /// Default stroke style
    static var defaultStrokeStyle: StrokeStyleType { .solid }
}
