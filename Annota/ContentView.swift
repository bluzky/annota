//
//  ContentView.swift
//  Annota
//
//  Created by Flex on 12/11/25.
//

import SwiftUI
import AppKit
import AnotarCanvas

struct ContentView: View {
    @StateObject private var viewModel = CanvasViewModel()
    @StateObject private var toolRegistry = ToolRegistry.shared
    @StateObject private var attributeStore = ToolAttributeStore()
    @EnvironmentObject private var settings: SettingsManager<AnnotaSettings>
    @State private var keyMonitor: Any?
    @State private var lastShapeTool: DrawingTool = .rectangle

    var body: some View {
        ZStack(alignment: .top) {
            // Canvas fills the entire space
            CanvasView(viewModel: viewModel)
                .frame(minWidth: 800, minHeight: 600)

            // Floating toolbars overlaid on top
            HStack {
                Spacer()
                VStack(spacing: 4) {
                    // Main toolbar - floating with top spacing
                    ToolbarView(viewModel: viewModel, toolRegistry: toolRegistry, lastShapeTool: $lastShapeTool)
                        .padding(.top, 12)

                    // Sub toolbar - floating directly below main toolbar (no spacing)
                    // Only show when there's content to display
                    if showSubToolbar {
                        SubToolbarView(viewModel: viewModel, toolRegistry: toolRegistry, attributeStore: attributeStore, lastShapeTool: $lastShapeTool)
                    }

                    Spacer()
                }
                Spacer()
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .navigationTitle(windowTitle)
        .focusedSceneObject(viewModel)
        .onAppear {
            AppState.shared.canvasViewModel = viewModel
            attributeStore.sync(to: viewModel)
            installKeyMonitor()
        }
        .onChange(of: viewModel.selectedTool) { _, newTool in
            attributeStore.sync(to: viewModel)
            // Track the last-used shape tool
            if toolRegistry.tool(for: newTool)?.category == .shape {
                lastShapeTool = newTool
            }
        }
        .onReceive(viewModel.$currentToolAttributes) { _ in
            // Persist changes made by framework-side controls (e.g. ArrowToolControls)
            attributeStore.persist(from: viewModel)
        }
        .onDisappear {
            if let monitor = keyMonitor {
                NSEvent.removeMonitor(monitor)
                keyMonitor = nil
            }
        }
    }

    private var windowTitle: String {
        if let url = viewModel.currentFileURL {
            let name = url.deletingPathExtension().lastPathComponent
            return viewModel.isDirty ? "\(name) — Edited" : name
        }
        return "Untitled"
    }

    // Check if sub-toolbar should be displayed
    private var showSubToolbar: Bool {
        if viewModel.selectionState.hasSelection {
            return true
        }
        // Check if current tool has relevant attributes to display
        let tool = toolRegistry.tool(for: viewModel.selectedTool)
        return tool?.category == .shape || tool?.category == .drawing || tool?.category == .annotation
    }

    // MARK: - Keyboard Shortcuts

    /// Build a mapping from key character → DrawingTool using current settings.
    /// The shape key maps to whatever the last-used shape tool is.
    private func toolKeyMap() -> [String: DrawingTool] {
        let keys = settings.current.toolKeys
        return [
            keys.select: .select,
            keys.hand: .hand,
            keys.text: .text,
            keys.shape: lastShapeTool,
            keys.line: .line,
            keys.arrow: .arrow,
            keys.pencil: .pencil,
        ]
    }

    /// Check if event matches a keyboard shortcut pattern (e.g., "cmd+shift+]")
    private func matchesShortcut(_ event: NSEvent, _ pattern: String) -> Bool {
        let parts = pattern.lowercased().split(separator: "+").map(String.init)
        guard let keyChar = parts.last else { return false }

        var expectedModifiers: NSEvent.ModifierFlags = []
        for part in parts.dropLast() {
            switch part {
            case "cmd", "command": expectedModifiers.insert(.command)
            case "shift": expectedModifiers.insert(.shift)
            case "ctrl", "control": expectedModifiers.insert(.control)
            case "opt", "option", "alt": expectedModifiers.insert(.option)
            default: break
            }
        }

        let actualModifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Special key mapping
        let eventKey: String
        if keyChar == "left" && event.keyCode == 123 {
            eventKey = "left"
        } else if keyChar == "right" && event.keyCode == 124 {
            eventKey = "right"
        } else if keyChar == "up" && event.keyCode == 126 {
            eventKey = "up"
        } else if keyChar == "down" && event.keyCode == 125 {
            eventKey = "down"
        } else if keyChar == "[" || keyChar == "]" {
            eventKey = event.characters?.lowercased() ?? ""
        } else {
            eventKey = event.charactersIgnoringModifiers?.lowercased() ?? ""
        }

        return actualModifiers == expectedModifiers && eventKey == keyChar
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Let text fields handle their own keyboard input
            if viewModel.isAnyObjectEditing {
                return event
            }

            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let keys = settings.current.commandKeys

            // Cmd+A: Select All
            if matchesShortcut(event, keys.selectAll) {
                viewModel.selectMultiple(ids: Set(viewModel.objects.map { $0.id }))
                return nil
            }

            // Cmd+C: Copy
            if matchesShortcut(event, keys.copy) {
                viewModel.copySelection()
                return nil
            }

            // Cmd+X: Cut
            if matchesShortcut(event, keys.cut) {
                viewModel.cutSelection()
                return nil
            }

            // Cmd+V: Paste
            if matchesShortcut(event, keys.paste) {
                viewModel.pasteFromClipboard(viewportSize: viewModel.canvasSize)
                return nil
            }

            // Cmd+Z: Undo
            if matchesShortcut(event, keys.undo) {
                viewModel.undoManager?.undo(on: viewModel)
                return nil
            }

            // Cmd+Shift+Z: Redo
            if matchesShortcut(event, keys.redo) {
                viewModel.undoManager?.redo(on: viewModel)
                return nil
            }

            // Z-order arrangement
            if matchesShortcut(event, keys.bringToFront) {
                viewModel.bringToFront()
                return nil
            }
            if matchesShortcut(event, keys.bringForward) {
                viewModel.bringForward()
                return nil
            }
            if matchesShortcut(event, keys.sendBackward) {
                viewModel.sendBackward()
                return nil
            }
            if matchesShortcut(event, keys.sendToBack) {
                viewModel.sendToBack()
                return nil
            }

            // Alignment (requires 2+ selected)
            if viewModel.selectionState.selectedIds.count >= 2 {
                if matchesShortcut(event, keys.alignLeft) {
                    viewModel.alignSelected(.left)
                    return nil
                }
                if matchesShortcut(event, keys.alignRight) {
                    viewModel.alignSelected(.right)
                    return nil
                }
                if matchesShortcut(event, keys.alignTop) {
                    viewModel.alignSelected(.top)
                    return nil
                }
                if matchesShortcut(event, keys.alignBottom) {
                    viewModel.alignSelected(.bottom)
                    return nil
                }
                if matchesShortcut(event, keys.alignCenterH) {
                    viewModel.alignSelected(.centerHorizontal)
                    return nil
                }
                if matchesShortcut(event, keys.alignCenterV) {
                    viewModel.alignSelected(.centerVertical)
                    return nil
                }
            }

            // Distribution (requires 3+ selected)
            if viewModel.selectionState.selectedIds.count >= 3 {
                if matchesShortcut(event, keys.distributeH) {
                    viewModel.distributeSelected(.horizontal)
                    return nil
                }
                if matchesShortcut(event, keys.distributeV) {
                    viewModel.distributeSelected(.vertical)
                    return nil
                }
            }

            // Delete (keyCode 51) or Forward Delete (keyCode 117)
            if modifiers.isEmpty && (event.keyCode == 51 || event.keyCode == 117) {
                if viewModel.selectionState.hasSelection {
                    viewModel.deleteSelected()
                    return nil
                }
            }

            // Tool quick keys — single key without modifiers switches the active tool
            if modifiers.isEmpty, let key = event.charactersIgnoringModifiers?.lowercased() {
                let map = toolKeyMap()
                if let tool = map[key] {
                    viewModel.selectedTool = tool
                    // Track shape tool for the toolbar shape picker
                    if ToolRegistry.shared.tool(for: tool)?.category == .shape {
                        lastShapeTool = tool
                    }
                    return nil
                }
            }

            return event
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(
            SettingsManager(
                defaults: AnnotaSettings(),
                storage: TOMLSettingsStorage(appName: "Annota")
            )
        )
}
