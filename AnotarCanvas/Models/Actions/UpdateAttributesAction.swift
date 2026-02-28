//
//  UpdateAttributesAction.swift
//  AnotarCanvas
//
//  Created by Claude on 2/27/26.
//

import Foundation

/// Action for updating attributes on one or more objects
@MainActor
public struct UpdateAttributesAction: CanvasAction {
    /// Object IDs that were updated
    private let objectIds: Set<UUID>

    /// Objects before the change (full snapshots)
    private let beforeObjects: [AnyCanvasObject]

    /// Objects after the change (full snapshots)
    private let afterObjects: [AnyCanvasObject]

    public init(objectIds: Set<UUID>, beforeObjects: [AnyCanvasObject], afterObjects: [AnyCanvasObject]) {
        self.objectIds = objectIds
        self.beforeObjects = beforeObjects
        self.afterObjects = afterObjects
    }

    public func execute(on viewModel: CanvasViewModel) {
        // Replace objects with their "after" state
        applyObjects(afterObjects, to: viewModel)
    }

    public func undo(on viewModel: CanvasViewModel) {
        // Replace objects with their "before" state
        applyObjects(beforeObjects, to: viewModel)
    }

    private func applyObjects(_ objects: [AnyCanvasObject], to viewModel: CanvasViewModel) {
        let objectsById = Dictionary(uniqueKeysWithValues: objects.map { ($0.id, $0) })

        for index in viewModel.objects.indices {
            if let replacement = objectsById[viewModel.objects[index].id] {
                viewModel._updateObjectAtIndex(index, with: replacement)
            }
        }
        viewModel.refreshSelectionCache()
    }

    public var description: String {
        objectIds.count == 1 ? "Update Attributes" : "Update \(objectIds.count) Objects"
    }
}
