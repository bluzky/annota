//
//  ObjectAttributes.swift
//  AnotarCanvas
//
//  Created for Toolbar & Batch Update System
//

import SwiftUI

/// Dictionary of attribute updates for batch operations
/// Enables type-erased property updates across different CanvasObject types
public typealias ObjectAttributes = [String: Any]

// MARK: - Well-Known Attribute Keys

public extension ObjectAttributes {
    // MARK: - Geometry Attributes (all CanvasObject)

    /// Object position in canvas coordinates
    static let position = "position"

    /// Object size (width, height)
    static let size = "size"

    /// Object rotation in radians
    static let rotation = "rotation"

    /// Z-index for layer ordering
    static let zIndex = "zIndex"

    /// Whether object is locked from editing
    static let isLocked = "isLocked"

    // MARK: - Stroke Attributes (StrokableObject)

    /// Stroke/outline color
    static let strokeColor = "strokeColor"

    /// Stroke width in points
    static let strokeWidth = "strokeWidth"

    /// Stroke style (solid, dashed, dotted, etc.)
    static let strokeStyle = "strokeStyle"

    // MARK: - Fill Attributes (FillableObject)

    /// Fill color
    static let fillColor = "fillColor"

    /// Fill opacity (0-1)
    static let fillOpacity = "fillOpacity"

    // MARK: - Text Attributes (TextContentObject)

    /// Text content
    static let text = "text"

    /// Text color
    static let textColor = "textColor"

    /// Font size in points
    static let fontSize = "fontSize"

    // MARK: - Custom Attributes (Tool-specific)

    /// Namespace for tool-specific custom attributes
    /// Value should be a [String: Any] dictionary containing tool-defined attributes
    /// This enables tools to add arbitrary attributes without framework modifications
    static let customAttributes = "customAttributes"
}
