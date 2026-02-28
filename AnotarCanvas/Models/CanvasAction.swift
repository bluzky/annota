//
//  CanvasAction.swift
//  AnotarCanvas
//
//  Created by Claude on 2/27/26.
//

import Foundation

/// Protocol for undoable actions on the canvas.
/// Each action captures the state needed to execute and undo itself.
@MainActor
public protocol CanvasAction {
    /// Execute this action on the given view model
    func execute(on viewModel: CanvasViewModel)

    /// Undo this action on the given view model
    func undo(on viewModel: CanvasViewModel)

    /// Human-readable description of this action (for debugging/UI)
    var description: String { get }
}
