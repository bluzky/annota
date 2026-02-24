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
        ]
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
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
