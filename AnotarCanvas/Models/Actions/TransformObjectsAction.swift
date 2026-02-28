//
//  TransformObjectsAction.swift
//  AnotarCanvas
//
//  Created by Claude on 2/27/26.
//

import Foundation

/// Stores geometry state (position, size, rotation) for an object
public struct ObjectGeometryState {
    public let id: UUID
    public let position: CGPoint
    public let size: CGSize
    public let rotation: CGFloat

    public init(id: UUID, position: CGPoint, size: CGSize, rotation: CGFloat) {
        self.id = id
        self.position = position
        self.size = size
        self.rotation = rotation
    }

    public init(from object: AnyCanvasObject) {
        self.id = object.id
        self.position = object.position
        self.size = object.size
        self.rotation = object.rotation
    }
}

/// Action for transforming objects (resize, rotate, or combined)
@MainActor
public struct TransformObjectsAction: CanvasAction {
    /// Geometry states before the transformation
    private let beforeStates: [ObjectGeometryState]

    /// Geometry states after the transformation
    private let afterStates: [ObjectGeometryState]

    public init(beforeStates: [ObjectGeometryState], afterStates: [ObjectGeometryState]) {
        self.beforeStates = beforeStates
        self.afterStates = afterStates
    }

    public func execute(on viewModel: CanvasViewModel) {
        // Apply the "after" states
        applyStates(afterStates, to: viewModel)
    }

    public func undo(on viewModel: CanvasViewModel) {
        // Apply the "before" states
        applyStates(beforeStates, to: viewModel)
    }

    private func applyStates(_ states: [ObjectGeometryState], to viewModel: CanvasViewModel) {
        for state in states {
            guard let index = viewModel.objects.firstIndex(where: { $0.id == state.id }) else { continue }
            let updated = viewModel.objects[index].applying([
                "position": state.position,
                "size": state.size,
                "rotation": state.rotation
            ])
            viewModel._updateObjectAtIndex(index, with: updated)
        }
        viewModel.refreshSelectionCache()
    }

    public var description: String {
        beforeStates.count == 1 ? "Transform Object" : "Transform \(beforeStates.count) Objects"
    }
}
