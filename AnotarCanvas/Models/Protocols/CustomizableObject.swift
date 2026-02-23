//
//  CustomizableObject.swift
//  AnotarCanvas
//
//  Protocol for objects that support tool-specific custom attributes
//

import Foundation

/// Protocol for objects that support tool-specific custom attributes.
/// Allows tools to define their own attributes without modifying the core framework.
///
/// Custom attributes are stored as string-keyed dictionaries, enabling complete
/// extensibility - new tools can add arbitrary attributes without framework changes.
public protocol CustomizableObject {
    /// Apply custom attributes to this object.
    /// Objects should pattern-match on known string keys and update their properties.
    ///
    /// - Parameter attributes: Dictionary of custom attribute key-value pairs
    ///
    /// Example:
    /// ```swift
    /// if let radius = attributes["borderRadius"] as? CGFloat {
    ///     self.borderRadius = radius
    /// }
    /// ```
    mutating func applyCustomAttributes(_ attributes: [String: Any])

    /// Extract custom attributes from this object.
    /// Returns a dictionary of current custom attribute values.
    /// Used by UI to display current values and handle multi-selection.
    ///
    /// - Returns: Dictionary of custom attribute key-value pairs
    ///
    /// Example:
    /// ```swift
    /// return [
    ///     "borderRadius": borderRadius,
    ///     "cornerStyle": cornerStyle.rawValue
    /// ]
    /// ```
    func getCustomAttributes() -> [String: Any]
}
