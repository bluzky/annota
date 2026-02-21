//
//  AnyCanvasObject.swift
//  texttool
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
struct AnyCanvasObject: Identifiable {
    let id: UUID

    /// Monotonically increasing version stamp.  Every `init` gets a unique value,
    /// so two wrappers compare as equal only when they are literally the same snapshot.
    /// This avoids enumerating every concrete-type field in `Equatable`.
    private let _version: UInt64
    @MainActor private static var _nextVersion: UInt64 = 0

    // Store the underlying object
    private let _object: Any

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

    /// The ObjectIdentifier for the concrete CanvasObject type stored inside this wrapper.
    /// Used by registries (ObjectViewRegistry, CodableObjectRegistry) for dynamic dispatch.
    let underlyingTypeId: ObjectIdentifier

    // MARK: - Initialization

    @MainActor
    init<T: CanvasObject>(_ object: T) {
        self.id = object.id
        self._version = Self._nextVersion
        Self._nextVersion += 1
        self._object = object
        self.underlyingTypeId = ObjectIdentifier(T.self)
        self._usesControlPoints = object.usesControlPoints

        self._getPosition = { object.position }
        self._getSize = { object.size }
        self._getRotation = { object.rotation }
        self._getIsLocked = { object.isLocked }
        self._getZIndex = { object.zIndex }
        self._contains = { object.contains($0) }
        self._boundingBox = { object.boundingBox() }
        self._hitTest = { object.hitTest($0, threshold: $1) }
        self._intersectsRect = { object.intersectsRect($0) }

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

    var position: CGPoint { _getPosition() }
    var size: CGSize { _getSize() }
    var rotation: CGFloat { _getRotation() }
    var isLocked: Bool { _getIsLocked() }
    var zIndex: Int { _getZIndex() }

    // MARK: - CanvasObject Methods

    func contains(_ point: CGPoint) -> Bool {
        _contains(point)
    }

    func boundingBox() -> CGRect {
        _boundingBox()
    }

    func hitTest(_ point: CGPoint, threshold: CGFloat) -> HitTestResult? {
        _hitTest(point, threshold)
    }

    func intersectsRect(_ rect: CGRect) -> Bool {
        _intersectsRect(rect)
    }

    // MARK: - TextContentObject Properties (read-only)

    /// Whether the object is currently being edited (false if not a TextContentObject)
    var isEditing: Bool { _getIsEditing?() ?? false }

    /// The text content (empty string if not a TextContentObject)
    var text: String { _getText?() ?? "" }

    /// Whether the underlying object supports text editing
    var hasTextContent: Bool { _getIsEditing != nil }

    /// Whether this object uses control points instead of a selection box (e.g. lines)
    var usesControlPoints: Bool { _usesControlPoints }

    // MARK: - Type Casting
    // These always read from _object which is the immutable snapshot captured at init.
    // Callers that need the latest state should use the current AnyCanvasObject from the
    // ViewModel's objects array rather than caching old wrappers.

    /// Attempt to get the underlying object as a specific type
    func asType<T: CanvasObject>(_ type: T.Type) -> T? {
        _object as? T
    }

    /// Get as TextObject if applicable
    var asTextObject: TextObject? {
        _object as? TextObject
    }

    /// Get as ShapeObject if applicable
    var asShapeObject: ShapeObject? {
        _object as? ShapeObject
    }

    /// Get as ImageObject if applicable
    var asImageObject: ImageObject? {
        _object as? ImageObject
    }

    /// Get as LineObject if applicable
    var asLineObject: LineObject? {
        _object as? LineObject
    }

    // MARK: - Protocol Checks

    /// Check if underlying object conforms to StrokableObject
    var isStrokable: Bool {
        _object is any StrokableObject
    }

    /// Check if underlying object conforms to FillableObject
    var isFillable: Bool {
        _object is any FillableObject
    }
}

// MARK: - Equatable

extension AnyCanvasObject: Equatable {
    static func == (lhs: AnyCanvasObject, rhs: AnyCanvasObject) -> Bool {
        // Version is unique per init, so this catches every concrete-type field change
        // without needing to enumerate them (strokeColor, arrowheads, imageData, etc.).
        lhs.id == rhs.id && lhs._version == rhs._version
    }
}

// MARK: - Hashable

extension AnyCanvasObject: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
