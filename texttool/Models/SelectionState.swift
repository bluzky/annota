//
//  SelectionState.swift
//  texttool
//
//  Created by Claude on 2/18/26.
//

import Foundation

/// Manages selection state for canvas objects supporting multi-selection
struct SelectionState: Equatable {
    /// Set of currently selected object IDs
    private(set) var selectedIds: Set<UUID> = []

    /// Returns true if any objects are selected
    var hasSelection: Bool {
        !selectedIds.isEmpty
    }

    /// Returns true if exactly one object is selected
    var isSingleSelection: Bool {
        selectedIds.count == 1
    }

    /// Returns the single selected ID if exactly one object is selected
    var singleSelectedId: UUID? {
        isSingleSelection ? selectedIds.first : nil
    }

    // MARK: - Query Methods

    /// Check if a specific object is selected
    func isSelected(_ id: UUID) -> Bool {
        selectedIds.contains(id)
    }

    // MARK: - Mutation Methods

    /// Select a single object, clearing any previous selection
    mutating func select(_ id: UUID) {
        selectedIds = [id]
    }

    /// Add an object to the selection (for shift+click)
    mutating func addToSelection(_ id: UUID) {
        selectedIds.insert(id)
    }

    /// Toggle selection state of an object (for shift+click)
    mutating func toggleSelection(_ id: UUID) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }

    /// Select multiple objects (for marquee selection)
    mutating func selectMultiple(_ ids: Set<UUID>) {
        selectedIds = ids
    }

    /// Add multiple objects to selection (for shift+marquee)
    mutating func addMultipleToSelection(_ ids: Set<UUID>) {
        selectedIds.formUnion(ids)
    }

    /// Clear all selection
    mutating func clear() {
        selectedIds.removeAll()
    }
}
