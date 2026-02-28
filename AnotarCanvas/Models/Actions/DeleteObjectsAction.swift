//
//  DeleteObjectsAction.swift
//  AnotarCanvas
//
//  Created by Claude on 2/27/26.
//

import Foundation

/// Action for deleting one or more objects from the canvas
@MainActor
public struct DeleteObjectsAction: CanvasAction {
    /// The objects that were deleted (with their full state for restoration)
    private let deletedObjects: [AnyCanvasObject]

    /// The selection state before deletion
    private let previousSelection: Set<UUID>

    public init(deletedObjects: [AnyCanvasObject], previousSelection: Set<UUID>) {
        self.deletedObjects = deletedObjects
        self.previousSelection = previousSelection
    }

    public func execute(on viewModel: CanvasViewModel) {
        // Remove all deleted objects
        let idsToRemove = Set(deletedObjects.map { $0.id })
        viewModel._removeObjects(ids: idsToRemove)
        viewModel.selectionState.clear()
    }

    public func undo(on viewModel: CanvasViewModel) {
        // Re-add all deleted objects
        for obj in deletedObjects {
            viewModel._addObjectDirectly(obj)
        }
        // Restore selection
        viewModel._setSelection(previousSelection)
    }

    public var description: String {
        deletedObjects.count == 1 ? "Delete Object" : "Delete \(deletedObjects.count) Objects"
    }
}
