//
//  ToolbarView.swift
//  Annota
//
//  Created by Flex on 12/11/25.
//

import SwiftUI
import AnotarCanvas

struct ToolbarView: View {
    @ObservedObject var viewModel: CanvasViewModel
    @ObservedObject var toolRegistry: ToolRegistry
    /// Tracks the last-used shape tool so clicking the shape button re-selects it.
    @Binding var lastShapeTool: DrawingTool

    var body: some View {
        HStack(spacing: 20) {
            // Tool Selection — order is an application-level concern, hardcoded here.
            // Shape-category tools are rendered as a single popover button (shapePickerButton).
            HStack(spacing: 4) {
                toolButton(.select, icon: "pointer.arrow", tooltip: "Select")
                toolButton(.hand, icon: "hand.raised", tooltip: "Hand")
                shapePickerButton
                toolButton(.line, icon: "line.diagonal", tooltip: "Line")
                toolButton(.arrow, icon: "arrow.right", tooltip: "Arrow")
                toolButton(.text, icon: "textformat", tooltip: "Text")
            }
            Divider()
                .frame(height: 20)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }

    private var activeShapeIcon: String {
        // Map tool IDs to icons (app responsibility - framework doesn't handle UI concerns)
        let shapeIcons: [String: String] = [
            "rectangle": "rectangle",
            "oval": "circle",
            "triangle": "triangle",
            "diamond": "diamond",
            "star": "star",
        ]
        return shapeIcons[lastShapeTool.id] ?? "square.on.square"
    }

    /// A single toolbar button that activates the last-used shape tool on click.
    @ViewBuilder
    private var shapePickerButton: some View {
        let activeTool = toolRegistry.tool(for: viewModel.selectedTool)
        let isShapeActive = activeTool?.category == .shape
        let icon = activeShapeIcon

        Button(action: {
            viewModel.selectedTool = lastShapeTool
        }) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .background(isShapeActive ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(6)
        .help("Shapes")
    }

    @ViewBuilder
    private func toolButton(_ tool: DrawingTool, icon: String, tooltip: String) -> some View {
        Button(action: {
            viewModel.selectedTool = tool
        }) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .background(viewModel.selectedTool == tool ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(6)
        .help(tooltip)
    }
}
