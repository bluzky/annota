//
//  FillableObject.swift
//  AnotarCanvas
//
//  Created by Claude on 2/18/26.
//

import SwiftUI

/// Protocol for canvas objects that can have a fill color
public protocol FillableObject: CanvasObject {
    /// The fill color of this object
    var fillColor: Color { get set }

    /// The opacity of the fill (0.0 to 1.0)
    var fillOpacity: CGFloat { get set }
}

// MARK: - Default Implementations

public extension FillableObject {
    /// Returns true if this object has a visible fill
    public var hasFill: Bool {
        fillOpacity > 0
    }

    /// Returns the fill color with opacity applied
    public var effectiveFillColor: Color {
        fillColor.opacity(fillOpacity)
    }
}

// MARK: - Default Values

public extension FillableObject {
    /// Default fill color
    public static var defaultFillColor: Color { .white }

    /// Default fill opacity
    public static var defaultFillOpacity: CGFloat { 1.0 }
}

