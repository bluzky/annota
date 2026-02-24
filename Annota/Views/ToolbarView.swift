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
    @EnvironmentObject var settings: SettingsManager<AnnotaSettings>
    /// Tracks the last-used shape tool so clicking the shape button re-selects it.
    @Binding var lastShapeTool: DrawingTool

    private var keys: ToolKeySettings { settings.current.toolKeys }

    var body: some View {
        HStack(spacing: 4) {
            toolButton(.select, icon: "pointer.arrow", label: "Select", key: keys.select)
            toolButton(.hand, icon: "hand.raised", label: "Hand", key: keys.hand)
            shapePickerButton
            toolButton(.line, icon: "line.diagonal", label: "Line", key: keys.line)
            toolButton(.arrow, icon: "arrow.right", label: "Arrow", key: keys.arrow)
            toolButton(.text, icon: "textformat", label: "Text", key: keys.text)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
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

    /// Quick key for the shape tool group (activates last-used shape).
    private var shapeKey: String { keys.shape }

    /// A single toolbar button that activates the last-used shape tool on click.
    @ViewBuilder
    private var shapePickerButton: some View {
        let activeTool = toolRegistry.tool(for: viewModel.selectedTool)
        let isShapeActive = activeTool?.category == .shape
        let icon = activeShapeIcon
        let key = shapeKey

        VStack(spacing: 1) {
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
            .tooltip("Shapes (\(key.uppercased()))")

            Text(key.uppercased())
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary.opacity(0.5))
        }
    }

    @ViewBuilder
    private func toolButton(_ tool: DrawingTool, icon: String, label: String, key: String) -> some View {
        VStack(spacing: 1) {
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
            .tooltip("\(label) (\(key.uppercased()))")

            Text(key.uppercased())
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary.opacity(0.5))
        }
    }
}
