//
//  MoveObjectsAction.swift
//  AnotarCanvas
//
//  Created by Claude on 2/27/26.
//

import Foundation

/// Action for moving one or more objects
@MainActor
public struct MoveObjectsAction: CanvasAction {
    /// Object IDs that were moved
    private let objectIds: Set<UUID>

    /// Positions before the move (keyed by object ID)
    private let beforePositions: [UUID: CGPoint]

    /// Positions after the move (keyed by object ID)
    private let afterPositions: [UUID: CGPoint]

    public init(objectIds: Set<UUID>, beforePositions: [UUID: CGPoint], afterPositions: [UUID: CGPoint]) {
        self.objectIds = objectIds
        self.beforePositions = beforePositions
        self.afterPositions = afterPositions
    }

    public func execute(on viewModel: CanvasViewModel) {
        // Apply the "after" positions
        applyPositions(afterPositions, to: viewModel)
    }

    public func undo(on viewModel: CanvasViewModel) {
        // Apply the "before" positions
        applyPositions(beforePositions, to: viewModel)
    }

    private func applyPositions(_ positions: [UUID: CGPoint], to viewModel: CanvasViewModel) {
        for (id, position) in positions {
            guard let index = viewModel.objects.firstIndex(where: { $0.id == id }) else { continue }
            let updated = viewModel.objects[index].applying(["position": position])
            viewModel._updateObjectAtIndex(index, with: updated)
        }
        viewModel.refreshSelectionCache()
    }

    public var description: String {
        objectIds.count == 1 ? "Move Object" : "Move \(objectIds.count) Objects"
    }
}
