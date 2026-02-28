//
//  CanvasFileCommands.swift
//  Annota
//
//  Adds "Export as PNG…" and "Export as JPEG…" items to the File menu.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import AnotarCanvas

struct CanvasFileCommands: Commands {
    @FocusedObject private var focusedViewModel: CanvasViewModel?

    private var hasObjects: Bool {
        let vm = focusedViewModel ?? AppState.shared.canvasViewModel
        return !(vm?.objects.isEmpty ?? true)
    }

    var body: some Commands {
        CommandGroup(after: .saveItem) {
            Divider()

            Button("Copy Image to Clipboard") {
                AppState.shared.copyToClipboard()
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(!hasObjects)

            Divider()

            Button("Export as PNG…") {
                AppState.shared.requestExport(format: .png)
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(!hasObjects)

            Button("Export as JPEG…") {
                AppState.shared.requestExport(format: .jpeg)
            }
            .disabled(!hasObjects)
        }
    }
}
