//
//  Capabilities.swift
//  AnotarCanvas
//
//  Unified capability system for tools and objects.
//  Replaces hardcoded boolean flags with extensible string-based declarations.
//

import Foundation

/// Capability identifier - what a tool or object supports
/// Used for both tool capabilities (what a tool creates) and object capabilities (what an object supports for editing)
public struct Capability: Hashable, ExpressibleByStringLiteral {
    public let identifier: String

    public init(_ identifier: String) {
        self.identifier = identifier
    }

    public init(stringLiteral value: String) {
        self.identifier = value
    }

    // MARK: - Tool Capabilities (what tools create/support)

    /// Tool supports label/text annotation on created objects
    public static let labelText: Capability = "labelText"

    /// Tool creates objects with stroke capability
    public static let stroke: Capability = "stroke"

    /// Tool creates objects with fill capability
    public static let fill: Capability = "fill"

    /// Tool supports shape-specific attributes (corner radius, etc.)
    public static let shapeAttributes: Capability = "shapeAttributes"

    /// Tool supports text formatting (font, size, alignment)
    public static let textFormatting: Capability = "textFormatting"

    /// Tool creates connectors/arrows with arrowhead controls
    public static let arrowheads: Capability = "arrowheads"

    /// Tool supports pen pressure/tilt (Apple Pencil)
    public static let pressureSensitive: Capability = "pressureSensitive"

    // MARK: - Object Capabilities (what objects support for editing)

    /// Object supports text editing
    public static let textContent: Capability = "textContent"

    /// Object supports text alignment
    public static let textAlignment: Capability = "textAlignment"

    /// Object can be resized
    public static let resize: Capability = "resize"

    /// Object can be rotated
    public static let rotate: Capability = "rotate"
}

// MARK: - Hashable Conformance

extension Capability {
    public static func == (lhs: Capability, rhs: Capability) -> Bool {
        lhs.identifier == rhs.identifier
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
}

// MARK: - Type Aliases for Clarity

/// Type alias for tool capabilities (what a tool supports when creating objects)
public typealias ToolCapability = Capability

/// Type alias for object capabilities (what an object supports for editing)
public typealias ObjectCapability = Capability
