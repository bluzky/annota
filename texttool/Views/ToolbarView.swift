//
//  ToolbarView.swift
//  texttool
//
//  Created by Flex on 12/11/25.
//

import SwiftUI
import AnotarCanvas

struct ToolbarView: View {
    @ObservedObject var viewModel: CanvasViewModel
    @ObservedObject var toolRegistry: ToolRegistry
    @State private var showShapePicker = false

    var body: some View {
        HStack(spacing: 20) {
            // Tool Selection — order is an application-level concern, hardcoded here.
            // Shape-category tools are rendered as a single popover button (shapePickerButton).
            HStack(spacing: 4) {
                toolButton(.select, icon: "arrow.up.left", tooltip: "Select")
                toolButton(.hand, icon: "hand.raised", tooltip: "Hand")
                shapePickerButton
                toolButton(.line, icon: "line.diagonal", tooltip: "Line")
                toolButton(.arrow, icon: "arrow.right", tooltip: "Arrow")
                toolButton(.text, icon: "textformat", tooltip: "Text")
            }
            Divider()
                .frame(height: 20)

            // Text Size Picker
            Text("Size:")
                .foregroundColor(.secondary)
            Picker("Size", selection: $viewModel.activeTextSize) {
                ForEach([12, 14, 16, 18, 24, 36, 48, 72], id: \.self) { size in
                    Text("\(Int(size))").tag(CGFloat(size))
                }
            }
            .labelsHidden()
            .frame(width: 80)
            .disabled(toolRegistry.tool(for: viewModel.selectedTool)?.category != .annotation)

            // Color Picker
            ColorPicker("Color", selection: $viewModel.activeColor)
                .labelsHidden()
                .frame(width: 60)

            Divider()
                .frame(height: 20)

            // Auto-resize toggle
            Toggle("Auto-resize", isOn: $viewModel.autoResizeShapes)
                .toggleStyle(.checkbox)
                .help("Automatically resize shapes to fit text")

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
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

        let activeTool = toolRegistry.tool(for: viewModel.selectedTool)
        if activeTool?.category == .shape {
            return shapeIcons[viewModel.selectedTool.id] ?? "square.on.square"
        }
        return "square.on.square"
    }

    /// A single toolbar button that shows the active shape's icon (or a generic squares icon
    /// when no shape tool is selected) and opens the shape picker popover on tap.
    @ViewBuilder
    private var shapePickerButton: some View {
        let activeTool = toolRegistry.tool(for: viewModel.selectedTool)
        let isShapeActive = activeTool?.category == .shape
        let icon = activeShapeIcon

        Button(action: {
            showShapePicker.toggle()
        }) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .background(isShapeActive ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(6)
        .help("Shapes")
        .popover(isPresented: $showShapePicker, arrowEdge: .bottom) {
            ShapePickerView(viewModel: viewModel, isPresented: $showShapePicker)
        }
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
