//
//  SelectionCapabilities.swift
//  AnotarCanvas
//
//  Created for Toolbar & Batch Update System
//

import Foundation

/// Describes what capabilities are available for the current selection
/// Used by UI to conditionally show/hide controls based on selected objects
public struct SelectionCapabilities {
    /// All selected objects support stroke operations
    public let canStroke: Bool

    /// All selected objects support fill operations
    public let canFill: Bool

    /// All selected objects support text editing
    public let canEditText: Bool

    /// Selected objects can be resized
    public let canResize: Bool

    /// Selected objects can be rotated
    public let canRotate: Bool

    /// Number of objects currently selected
    public let objectCount: Int

    /// Factory method to determine capabilities from selected objects
    public static func from(objects: [AnyCanvasObject]) -> SelectionCapabilities {
        guard !objects.isEmpty else {
            return SelectionCapabilities(
                canStroke: false,
                canFill: false,
                canEditText: false,
                canResize: false,
                canRotate: false,
                objectCount: 0
            )
        }

        return SelectionCapabilities(
            canStroke: objects.allSatisfy { $0.isStrokable },
            canFill: objects.allSatisfy { $0.isFillable },
            canEditText: objects.allSatisfy { $0.hasTextContent },
            canResize: true,
            canRotate: true,
            objectCount: objects.count
        )
    }

    /// Empty capabilities (no selection)
    public static var empty: SelectionCapabilities {
        SelectionCapabilities(
            canStroke: false,
            canFill: false,
            canEditText: false,
            canResize: false,
            canRotate: false,
            objectCount: 0
        )
    }
}
