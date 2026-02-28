//
//  UndoManager.swift
//  AnotarCanvas
//
//  Created by Claude on 2/27/26.
//

import Foundation
import Combine

/// Manages undo/redo stacks for canvas actions.
/// Maintains a history of actions and supports undo/redo operations.
@MainActor
public class UndoManager: ObservableObject {
    /// Maximum number of actions to keep in the undo stack
    public var maxStackSize: Int

    /// Stack of actions that can be undone
    @Published private(set) var undoStack: [CanvasAction] = []

    /// Stack of actions that can be redone
    @Published private(set) var redoStack: [CanvasAction] = []

    /// Whether there are actions that can be undone
    public var canUndo: Bool {
        !undoStack.isEmpty
    }

    /// Whether there are actions that can be redone
    public var canRedo: Bool {
        !redoStack.isEmpty
    }

    /// Initialize with a maximum stack size
    /// - Parameter maxStackSize: Maximum number of actions to keep (default: 100)
    public init(maxStackSize: Int = 100) {
        self.maxStackSize = maxStackSize
    }

    /// Record a new action. This executes the action and adds it to the undo stack.
    /// Recording a new action clears the redo stack.
    /// - Parameters:
    ///   - action: The action to record
    ///   - viewModel: The view model to execute the action on
    public func record(_ action: CanvasAction, on viewModel: CanvasViewModel) {
        // Execute the action
        action.execute(on: viewModel)

        // Add to undo stack
        undoStack.append(action)

        // Trim stack if needed
        if undoStack.count > maxStackSize {
            undoStack.removeFirst()
        }

        // Clear redo stack (new action invalidates redo history)
        redoStack.removeAll()
    }

    /// Record an action without executing it (for actions that have already been executed)
    /// - Parameter action: The action to record
    public func recordWithoutExecuting(_ action: CanvasAction) {
        // Add to undo stack
        undoStack.append(action)

        // Trim stack if needed
        if undoStack.count > maxStackSize {
            undoStack.removeFirst()
        }

        // Clear redo stack (new action invalidates redo history)
        redoStack.removeAll()
    }

    /// Undo the most recent action
    /// - Parameter viewModel: The view model to undo the action on
    public func undo(on viewModel: CanvasViewModel) {
        guard let action = undoStack.popLast() else { return }

        // Undo the action
        action.undo(on: viewModel)

        // Add to redo stack
        redoStack.append(action)
    }

    /// Redo the most recently undone action
    /// - Parameter viewModel: The view model to redo the action on
    public func redo(on viewModel: CanvasViewModel) {
        guard let action = redoStack.popLast() else { return }

        // Re-execute the action
        action.execute(on: viewModel)

        // Add back to undo stack
        undoStack.append(action)
    }

    /// Clear all undo/redo history
    public func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
}
