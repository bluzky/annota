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
            Picker("Tool", selection: $viewModel.selectedTool) {
                Label("Select", systemImage: "cursorarrow").tag(DrawingTool.select)
                Label("Text", systemImage: "textformat").tag(DrawingTool.text)
                Label("Rectangle", systemImage: "rectangle").tag(DrawingTool.rectangle)
                Label("Circle", systemImage: "circle").tag(DrawingTool.circle)
            }
            .pickerStyle(.segmented)
            .frame(width: 360)

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
}
