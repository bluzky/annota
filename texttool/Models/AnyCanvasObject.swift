//
//  AnyCanvasObject.swift
//  texttool
//
//  Created by Claude on 2/18/26.
//

import SwiftUI

/// Type-erased wrapper for CanvasObject to enable heterogeneous collections
struct AnyCanvasObject: Identifiable {
    let id: UUID

    // Store the underlying object
    private let _object: Any

    // Store closures for protocol methods
    private let _getPosition: () -> CGPoint
    private let _setPosition: (CGPoint) -> Void
    private let _getSize: () -> CGSize
    private let _setSize: (CGSize) -> Void
    private let _getRotation: () -> CGFloat
    private let _setRotation: (CGFloat) -> Void
    private let _getIsLocked: () -> Bool
    private let _setIsLocked: (Bool) -> Void
    private let _getZIndex: () -> Int
    private let _setZIndex: (Int) -> Void
    private let _contains: (CGPoint) -> Bool
    private let _boundingBox: () -> CGRect
    private let _hitTest: (CGPoint, CGFloat) -> HitTestResult?

    // TextContentObject closures (nil when underlying type doesn't conform)
    private let _getIsEditing: (() -> Bool)?
    private let _setIsEditing: ((Bool) -> Void)?
    private let _getText: (() -> String)?
    private let _setText: ((String) -> Void)?

    // Rebuild closure: extracts the mutated underlying object back into a new AnyCanvasObject
    private let _rebuild: () -> AnyCanvasObject

    // Type information
    let objectType: ObjectType

    enum ObjectType {
        case text
        case shape
        case line
        case arrow
        case pencil
        case highlighter
        case autoNumber
        case sticker
        case note
        case image
        case mosaic
        case unknown
    }

    // MARK: - Initialization

    init<T: CanvasObject>(_ object: T) {
        self.id = object.id
        self._object = object

        // Determine object type
        switch object {
        case is TextObject:
            self.objectType = .text
        case is ShapeObject:
            self.objectType = .shape
        case let lineObj as LineObject:
            self.objectType = lineObj.isArrow ? .arrow : .line
        case is ImageObject:
            self.objectType = .image
        default:
            self.objectType = .unknown
        }

        // Create mutable copy for setters
        var mutableObject = object

        self._getPosition = { mutableObject.position }
        self._setPosition = { mutableObject.position = $0 }
        self._getSize = { mutableObject.size }
        self._setSize = { mutableObject.size = $0 }
        self._getRotation = { mutableObject.rotation }
        self._setRotation = { mutableObject.rotation = $0 }
        self._getIsLocked = { mutableObject.isLocked }
        self._setIsLocked = { mutableObject.isLocked = $0 }
        self._getZIndex = { mutableObject.zIndex }
        self._setZIndex = { mutableObject.zIndex = $0 }
        self._contains = { mutableObject.contains($0) }
        self._boundingBox = { mutableObject.boundingBox() }
        self._hitTest = { mutableObject.hitTest($0, threshold: $1) }

        // TextContentObject closures — set only when the underlying type conforms
        // IMPORTANT: Closures must mutate mutableObject, not a separate copy
        if mutableObject is any TextContentObject {
            self._getIsEditing = { (mutableObject as! any TextContentObject).isEditing }
            self._setIsEditing = { newValue in
                var textContent = mutableObject as! any TextContentObject
                textContent.isEditing = newValue
                mutableObject = textContent as! T
            }
            self._getText = { (mutableObject as! any TextContentObject).text }
            self._setText = { newValue in
                var textContent = mutableObject as! any TextContentObject
                textContent.text = newValue
                mutableObject = textContent as! T
            }
        } else {
            self._getIsEditing = nil
            self._setIsEditing = nil
            self._getText = nil
            self._setText = nil
        }

        self._rebuild = { AnyCanvasObject(mutableObject) }
    }

    // MARK: - CanvasObject Properties

    var position: CGPoint {
        get { _getPosition() }
        nonmutating set { _setPosition(newValue) }
    }

    var size: CGSize {
        get { _getSize() }
        nonmutating set { _setSize(newValue) }
    }

    var rotation: CGFloat {
        get { _getRotation() }
        nonmutating set { _setRotation(newValue) }
    }

    var isLocked: Bool {
        get { _getIsLocked() }
        nonmutating set { _setIsLocked(newValue) }
    }

    var zIndex: Int {
        get { _getZIndex() }
        nonmutating set { _setZIndex(newValue) }
    }

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

    // MARK: - TextContentObject Properties

    /// Whether the object is currently being edited (nil if not a TextContentObject)
    var isEditing: Bool {
        get { _getIsEditing?() ?? false }
        nonmutating set { _setIsEditing?(newValue) }
    }

    /// The text content (empty string if not a TextContentObject)
    var text: String {
        get { _getText?() ?? "" }
        nonmutating set { _setText?(newValue) }
    }

    /// Whether the underlying object supports text editing
    var hasTextContent: Bool {
        _getIsEditing != nil
    }

    // MARK: - Snapshot

    /// Returns a new AnyCanvasObject reflecting any mutations made via nonmutating setters.
    /// Call this after mutating through the type-erased properties to persist changes
    /// back into the `objects` array (which stores value types).
    func rebuilt() -> AnyCanvasObject {
        _rebuild()
    }

    // MARK: - Type Casting

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
        guard lhs.id == rhs.id else { return false }
        // Compare geometric state and text content so SwiftUI re-renders when anything changes
        return lhs.position == rhs.position
            && lhs.size == rhs.size
            && lhs.rotation == rhs.rotation
            && lhs.zIndex == rhs.zIndex
            && lhs.isEditing == rhs.isEditing
            && lhs.text == rhs.text
    }
}

// MARK: - Hashable

extension AnyCanvasObject: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
