//
//  ContentView.swift
//  texttool
//
//  Created by Flex on 12/11/25.
//

import SwiftUI
import AppKit
import AnotarCanvas

struct ContentView: View {
    @StateObject private var viewModel = CanvasViewModel()
    @State private var keyMonitor: Any?

    var body: some View {
        VStack(spacing: 0) {
            ToolbarView(viewModel: viewModel, toolRegistry: ToolRegistry.shared)
            CanvasView(viewModel: viewModel)
        }
        .frame(minWidth: 800, minHeight: 600)
        .focusedSceneObject(viewModel)
        .onAppear {
            AppState.shared.canvasViewModel = viewModel
            installKeyMonitor()
        }
        .onDisappear {
            if let monitor = keyMonitor {
                NSEvent.removeMonitor(monitor)
                keyMonitor = nil
            }
        }
    }

    // MARK: - Keyboard Shortcuts

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak viewModel] event in
            guard let viewModel else { return event }

            // Let text fields handle their own keyboard input
            if viewModel.isAnyObjectEditing {
                return event
            }

            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // Cmd+C: Copy
            if modifiers == .command && event.charactersIgnoringModifiers == "c" {
                viewModel.copySelection()
                return nil
            }

            // Cmd+X: Cut
            if modifiers == .command && event.charactersIgnoringModifiers == "x" {
                viewModel.cutSelection()
                return nil
            }

            // Cmd+V: Paste
            if modifiers == .command && event.charactersIgnoringModifiers == "v" {
                viewModel.pasteFromClipboard(viewportSize: viewModel.canvasSize)
                return nil
            }

            // Delete (keyCode 51) or Forward Delete (keyCode 117)
            if modifiers.isEmpty && (event.keyCode == 51 || event.keyCode == 117) {
                if viewModel.selectionState.hasSelection {
                    viewModel.deleteSelected()
                    return nil
                }
            }

            return event
        }
    }
}

#Preview {
    ContentView()
}
