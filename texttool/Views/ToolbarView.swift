//
//  ToolbarView.swift
//  texttool
//
//  Created by Flex on 12/11/25.
//

import SwiftUI

struct ToolbarView: View {
    @ObservedObject var viewModel: CanvasViewModel

    var body: some View {
        HStack(spacing: 20) {
            // Tool Selection
            HStack(spacing: 4) {
                toolButton(.select, icon: "cursorarrow", tooltip: "Select")
                toolButton(.hand, icon: "hand.raised", tooltip: "Hand")
                toolButton(.rectangle, icon: "rectangle", tooltip: "Rectangle")
                toolButton(.circle, icon: "circle", tooltip: "Circle")
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
            .disabled(viewModel.selectedTool != .text)

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
