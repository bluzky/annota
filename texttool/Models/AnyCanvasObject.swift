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

    // Type information
    let objectType: ObjectType

    enum ObjectType {
        case text
        case rectangle
        case circle
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
        case is RectangleObject:
            self.objectType = .rectangle
        case is CircleObject:
            self.objectType = .circle
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

    // MARK: - Type Casting

    /// Attempt to get the underlying object as a specific type
    func asType<T: CanvasObject>(_ type: T.Type) -> T? {
        _object as? T
    }

    /// Get as TextObject if applicable
    var asTextObject: TextObject? {
        _object as? TextObject
    }

    /// Get as RectangleObject if applicable
    var asRectangleObject: RectangleObject? {
        _object as? RectangleObject
    }

    /// Get as CircleObject if applicable
    var asCircleObject: CircleObject? {
        _object as? CircleObject
    }

    // MARK: - Protocol Checks

    /// Check if underlying object conforms to TextContentObject
    var hasTextContent: Bool {
        _object is any TextContentObject
    }

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
        lhs.id == rhs.id
    }
}

// MARK: - Hashable

extension AnyCanvasObject: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
