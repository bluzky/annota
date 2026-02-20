//
//  CanvasFileCommands.swift
//  texttool
//
//  Adds "Export as PNG…" and "Export as JPEG…" items to the File menu.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct CanvasFileCommands: Commands {
    @FocusedObject private var focusedViewModel: CanvasViewModel?

    private var hasObjects: Bool {
        let vm = focusedViewModel ?? AppState.shared.canvasViewModel
        return !(vm?.objects.isEmpty ?? true)
    }

    var body: some Commands {
        CommandGroup(after: .saveItem) {
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
