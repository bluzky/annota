//
//  CanvasFileCommands.swift
//  Annota
//
//  Adds Save/Open and Export items to the File menu.
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
        // Replace the default Save item with our own Save/Open commands
        CommandGroup(replacing: .saveItem) {
            Button("Open…") {
                AppState.shared.openFile()
            }
            .keyboardShortcut("o", modifiers: .command)

            Divider()

            Button("Save") {
                AppState.shared.saveFile()
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(!hasObjects)

            Button("Save As…") {
                AppState.shared.saveFileAs()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(!hasObjects)
        }

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
