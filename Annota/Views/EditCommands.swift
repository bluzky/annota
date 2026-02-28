//
//  EditCommands.swift
//  Annota
//
//  Adds undo/redo commands to the Edit menu.
//

import SwiftUI
import AnotarCanvas

struct EditCommands: Commands {
    @FocusedObject private var focusedViewModel: CanvasViewModel?

    private var viewModel: CanvasViewModel? {
        focusedViewModel ?? AppState.shared.canvasViewModel
    }

    private var canUndo: Bool {
        viewModel?.undoManager?.canUndo ?? false
    }

    private var canRedo: Bool {
        viewModel?.undoManager?.canRedo ?? false
    }

    var body: some Commands {
        CommandGroup(before: .pasteboard) {
            Button("Undo") {
                guard let vm = viewModel else { return }
                vm.undoManager?.undo(on: vm)
            }
            .keyboardShortcut("z", modifiers: [.command])
            .disabled(!canUndo)

            Button("Redo") {
                guard let vm = viewModel else { return }
                vm.undoManager?.redo(on: vm)
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(!canRedo)

            Divider()
        }
    }
}
