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
    /// Set of capabilities supported by ALL selected objects
    public let capabilities: Set<ObjectCapability>

    /// Number of objects currently selected
    public let objectCount: Int

    /// Factory method to determine capabilities from selected objects
    public static func from(objects: [AnyCanvasObject]) -> SelectionCapabilities {
        guard !objects.isEmpty else {
            return SelectionCapabilities(capabilities: [], objectCount: 0)
        }

        var commonCapabilities: Set<ObjectCapability> = [.resize, .rotate]

        // Add capability only if ALL objects support it
        if objects.allSatisfy({ $0.isStrokable }) {
            commonCapabilities.insert(.stroke)
        }
        if objects.allSatisfy({ $0.isFillable }) {
            commonCapabilities.insert(.fill)
        }
        if objects.allSatisfy({ $0.hasTextContent || $0.asLineObject != nil }) {
            commonCapabilities.insert(.textContent)
        }
        if objects.allSatisfy({ $0.hasTextContent }) {
            commonCapabilities.insert(.textAlignment)
        }

        return SelectionCapabilities(
            capabilities: commonCapabilities,
            objectCount: objects.count
        )
    }

    /// Empty capabilities (no selection)
    public static var empty: SelectionCapabilities {
        SelectionCapabilities(capabilities: [], objectCount: 0)
    }

    // MARK: - Convenience Checks

    /// Check if selection supports a capability
    public func supports(_ capability: ObjectCapability) -> Bool {
        capabilities.contains(capability)
    }
}
