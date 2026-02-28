//
//  AddObjectAction.swift
//  AnotarCanvas
//
//  Created by Claude on 2/27/26.
//

import Foundation

/// Action for adding a new object to the canvas
@MainActor
public struct AddObjectAction: CanvasAction {
    /// The object that was added
    private let object: AnyCanvasObject

    /// The z-index assigned to the object
    private let zIndex: Int

    public init(object: AnyCanvasObject, zIndex: Int) {
        self.object = object
        self.zIndex = zIndex
    }

    public func execute(on viewModel: CanvasViewModel) {
        // Re-add the object with its original ID and z-index
        viewModel._addObjectDirectly(object)
    }

    public func undo(on viewModel: CanvasViewModel) {
        // Remove the object by ID
        viewModel.removeObject(withId: object.id)
    }

    public var description: String {
        "Add Object"
    }
}
