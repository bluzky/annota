//
//  FillableObject.swift
//  texttool
//
//  Created by Claude on 2/18/26.
//

import SwiftUI

/// Protocol for canvas objects that can have a fill color
protocol FillableObject: CanvasObject {
    /// The fill color of this object
    var fillColor: Color { get set }

    /// The opacity of the fill (0.0 to 1.0)
    var fillOpacity: CGFloat { get set }
}

// MARK: - Default Implementations

extension FillableObject {
    /// Returns true if this object has a visible fill
    var hasFill: Bool {
        fillOpacity > 0
    }

    /// Returns the fill color with opacity applied
    var effectiveFillColor: Color {
        fillColor.opacity(fillOpacity)
    }
}

// MARK: - Default Values

extension FillableObject {
    /// Default fill color
    static var defaultFillColor: Color { .white }

    /// Default fill opacity
    static var defaultFillOpacity: CGFloat { 1.0 }
}

// MARK: - Combined Protocol

/// Protocol for objects that can have both stroke and fill
/// This is a convenience typealias for the common case
typealias ShapeObject = StrokableObject & FillableObject

/// Protocol for shape objects that also contain text
typealias TextShapeObject = TextContentObject & StrokableObject & FillableObject
