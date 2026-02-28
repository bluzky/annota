//
//  AnyCanvasObject.swift
//  AnotarCanvas
//
//  Created by Claude on 2/18/26.
//

import SwiftUI

/// Type-erased wrapper for CanvasObject to enable heterogeneous collections.
///
/// Mutation contract: All properties are read-only on AnyCanvasObject itself.
/// To mutate, callers must update the concrete object via CanvasViewModel helpers
/// (e.g. updateObjectFrame, updateText, updateShapeObject, updateLineObject) which
/// replace the wrapper in the @Published array and trigger SwiftUI re-renders.
///
/// The `rebuilt()` helper is retained for the handful of internal sites that need
/// to produce an updated wrapper from a locally mutated concrete copy — but the
/// nonmutating-setter pattern has been removed to eliminate the silent-desync footgun.
public struct AnyCanvasObject: Identifiable {
    public let id: UUID

    /// Monotonically increasing version stamp.  Every `init` gets a unique value,
    /// so two wrappers compare as equal only when they are literally the same snapshot.
    /// This avoids enumerating every concrete-type field in `Equatable`.
    private let _version: UInt64
    @MainActor private static var _nextVersion: UInt64 = 0

    // Store the underlying object
    private let _object: Any

    // Closures for type-erased mutation
    private let _mutate: (ObjectAttributes) -> Any
    private let _rebuild: (Any) -> AnyCanvasObject

    // Store closures for protocol methods
    private let _getPosition: () -> CGPoint
    private let _getSize: () -> CGSize
    private let _getRotation: () -> CGFloat
    private let _getIsLocked: () -> Bool
    private let _getZIndex: () -> Int
    private let _contains: (CGPoint) -> Bool
    private let _boundingBox: () -> CGRect
    private let _hitTest: (CGPoint, CGFloat) -> HitTestResult?
    private let _intersectsRect: (CGRect) -> Bool

    // TextContentObject closures (nil when underlying type doesn't conform)
    private let _getIsEditing: (() -> Bool)?
    private let _getText: (() -> String)?

    // Capability flags
    private let _usesControlPoints: Bool
    private let _supportsTextAlignment: Bool

    /// The ObjectIdentifier for the concrete CanvasObject type stored inside this wrapper.
    /// Used by registries (ObjectViewRegistry, CodableObjectRegistry) for dynamic dispatch.
    public let underlyingTypeId: ObjectIdentifier

    // MARK: - Initialization

    @MainActor
    init<T: CanvasObject>(_ object: T) {
        self.id = object.id
        self._version = Self._nextVersion
        Self._nextVersion += 1
        self._object = object
        self.underlyingTypeId = ObjectIdentifier(T.self)
        self._usesControlPoints = object.usesControlPoints

        // Check if object supports text alignment via protocol property
        self._supportsTextAlignment = (object as? any TextContentObject)?.supportsTextAlignment ?? false

        self._getPosition = { object.position }
        self._getSize = { object.size }
        self._getRotation = { object.rotation }
        self._getIsLocked = { object.isLocked }
        self._getZIndex = { object.zIndex }
        self._contains = { object.contains($0) }
        self._boundingBox = { object.boundingBox() }
        self._hitTest = { object.hitTest($0, threshold: $1) }
        self._intersectsRect = { object.intersectsRect($0) }

        // Capture mutation logic for type T
        self._mutate = { attributes in
            var mutableCopy = object
            Self.applyAttributesGeneric(attributes, to: &mutableCopy)
            return mutableCopy
        }

        // Capture rebuild logic for type T
        self._rebuild = { mutatedAny in
            guard let mutated = mutatedAny as? T else {
                fatalError("Type mismatch in rebuild")
            }
            return AnyCanvasObject(mutated)
        }

        // TextContentObject closures — set only when the underlying type conforms
        if let textObj = object as? any TextContentObject {
            self._getIsEditing = { textObj.isEditing }
            self._getText = { textObj.text }
        } else {
            self._getIsEditing = nil
            self._getText = nil
        }
    }

    // MARK: - CanvasObject Properties (read-only)

    public var position: CGPoint { _getPosition() }
    public var size: CGSize { _getSize() }
    public var rotation: CGFloat { _getRotation() }
    public var isLocked: Bool { _getIsLocked() }
    public var zIndex: Int { _getZIndex() }

    // MARK: - CanvasObject Methods

    public func contains(_ point: CGPoint) -> Bool {
        _contains(point)
    }

    public func boundingBox() -> CGRect {
        _boundingBox()
    }

    public func hitTest(_ point: CGPoint, threshold: CGFloat) -> HitTestResult? {
        _hitTest(point, threshold)
    }

    public func intersectsRect(_ rect: CGRect) -> Bool {
        _intersectsRect(rect)
    }

    // MARK: - TextContentObject Properties (read-only)

    /// Whether the object is currently being edited (false if not a TextContentObject)
    public var isEditing: Bool { _getIsEditing?() ?? false }

    /// The text content (empty string if not a TextContentObject)
    public var text: String { _getText?() ?? "" }

    /// Whether the underlying object supports text editing
    public var hasTextContent: Bool { _getIsEditing != nil }

    /// Whether this object supports text alignment controls (TextObject/ShapeObject yes, LineObject no)
    public var supportsTextAlignment: Bool { _supportsTextAlignment }

    /// Whether this object uses control points instead of a selection box (e.g. lines)
    public var usesControlPoints: Bool { _usesControlPoints }

    // MARK: - Type Casting
    // These always read from _object which is the immutable snapshot captured at init.
    // Callers that need the latest state should use the current AnyCanvasObject from the
    // ViewModel's objects array rather than caching old wrappers.

    /// Attempt to get the underlying object as a specific type
    ///
    /// This is the ONLY way to access concrete object types from AnyCanvasObject.
    /// Library users can add new object types without modifying this file.
    ///
    /// Example:
    /// ```swift
    /// if let shape = anyObject.asType(ShapeObject.self) {
    ///     print("Fill color: \(shape.fillColor)")
    /// }
    /// ```
    public func asType<T: CanvasObject>(_ type: T.Type) -> T? {
        _object as? T
    }

    // MARK: - Type-Erased Mutation

    /// Apply attributes and return a new wrapper with updated values
    /// This enables batch updates without requiring type-specific dispatch at call site
    @MainActor
    public func applying(_ attributes: ObjectAttributes) -> AnyCanvasObject {
        let mutated = _mutate(attributes)
        return _rebuild(mutated)
    }

    // MARK: - Generic Attribute Application

    /// Helper method to apply attributes to any CanvasObject type
    /// Handles geometry, stroke, fill, and text properties
    private static func applyAttributesGeneric<T: CanvasObject>(
        _ attributes: ObjectAttributes,
        to object: inout T
    ) {
        // Geometry (all CanvasObject)
        if let pos = attributes["position"] as? CGPoint {
            object.position = pos
        }
        if let size = attributes["size"] as? CGSize {
            object.size = size
        }
        if let rot = attributes["rotation"] as? CGFloat {
            object.rotation = rot
        }
        if let z = attributes["zIndex"] as? Int {
            object.zIndex = z
        }
        if let locked = attributes["isLocked"] as? Bool {
            object.isLocked = locked
        }

        // Stroke properties (protocol-based)
        if var strokeable = object as? any StrokableObject {
            var modified = false
            if let color = attributes["strokeColor"] as? Color {
                strokeable.strokeColor = color
                modified = true
            }
            if let width = attributes["strokeWidth"] as? CGFloat {
                strokeable.strokeWidth = width
                modified = true
            }
            if let style = attributes["strokeStyle"] as? StrokeStyleType {
                strokeable.strokeStyle = style
                modified = true
            }
            if modified, let updated = strokeable as? T {
                object = updated
            }
        }

        // Fill properties (protocol-based)
        if var fillable = object as? any FillableObject {
            var modified = false
            if let color = attributes["fillColor"] as? Color {
                fillable.fillColor = color
                modified = true
            }
            if let opacity = attributes["fillOpacity"] as? CGFloat {
                fillable.fillOpacity = opacity
                modified = true
            }
            if modified, let updated = fillable as? T {
                object = updated
            }
        }

        // Text properties (protocol-based)
        if var textContent = object as? any TextContentObject {
            var modified = false
            if let text = attributes["text"] as? String {
                textContent.text = text
                modified = true
            }
            if let editing = attributes["isEditing"] as? Bool {
                textContent.isEditing = editing
                modified = true
            }
            if let color = attributes["textColor"] as? Color {
                textContent.textAttributes.textColor = CodableColor(color)
                modified = true
            }
            if let size = attributes["fontSize"] as? CGFloat {
                textContent.textAttributes.fontSize = size
                modified = true
            }
            if let family = attributes["fontFamily"] as? String {
                textContent.textAttributes.fontFamily = family
                modified = true
            }
            if let hAlign = attributes[ObjectAttributes.horizontalTextAlignment] as? HorizontalTextAlignment {
                textContent.textAttributes.horizontalAlignment = hAlign
                modified = true
            }
            if let vAlign = attributes[ObjectAttributes.verticalTextAlignment] as? VerticalTextAlignment {
                textContent.textAttributes.verticalAlignment = vAlign
                modified = true
            }
            if modified, let updated = textContent as? T {
                object = updated
            }
        }

        // Line label text properties
        if var line = object as? LineObject {
            var modified = false
            if let color = attributes["textColor"] as? Color {
                line.labelAttributes.textColor = CodableColor(color)
                modified = true
            }
            if let size = attributes["fontSize"] as? CGFloat {
                line.labelAttributes.fontSize = size
                modified = true
            }
            if let family = attributes["fontFamily"] as? String {
                line.labelAttributes.fontFamily = family
                modified = true
            }
            if modified, let updated = line as? T {
                object = updated
            }
        }

        // Custom attributes (tool-specific, protocol-based)
        if let customAttrs = attributes[ObjectAttributes.customAttributes] as? [String: Any] {
            if var customizable = object as? any CustomizableObject {
                customizable.applyCustomAttributes(customAttrs)
                if let updated = customizable as? T {
                    object = updated
                }
            }
        }
    }

    // MARK: - Protocol Checks

    /// Check if underlying object conforms to StrokableObject
    public var isStrokable: Bool {
        _object is any StrokableObject
    }

    /// Check if underlying object conforms to FillableObject
    public var isFillable: Bool {
        _object is any FillableObject
    }

    /// Check if underlying object conforms to CustomizableObject
    public var isCustomizable: Bool {
        _object is any CustomizableObject
    }

    /// Get as CustomizableObject if applicable
    public var asCustomizable: (any CustomizableObject)? {
        _object as? any CustomizableObject
    }

    /// Get as StrokableObject if applicable
    /// Use this instead of hard-coding specific types like ShapeObject or LineObject
    public var asStrokable: (any StrokableObject)? {
        _object as? any StrokableObject
    }

    /// Get as FillableObject if applicable
    /// Use this instead of hard-coding specific types like ShapeObject
    public var asFillable: (any FillableObject)? {
        _object as? any FillableObject
    }

    /// Get as TextContentObject if applicable
    /// Use this instead of hard-coding specific types like TextObject or ShapeObject
    public var asTextContent: (any TextContentObject)? {
        _object as? any TextContentObject
    }
}

// MARK: - Equatable

extension AnyCanvasObject: Equatable {
    public static func == (lhs: AnyCanvasObject, rhs: AnyCanvasObject) -> Bool {
        // Version is unique per init, so this catches every concrete-type field change
        // without needing to enumerate them (strokeColor, arrowheads, imageData, etc.).
        lhs.id == rhs.id && lhs._version == rhs._version
    }
}

// MARK: - Hashable

extension AnyCanvasObject: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
