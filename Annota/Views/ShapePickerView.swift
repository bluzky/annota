//
//  ShapePickerView.swift
//  Annota
//

import SwiftUI
import AnotarCanvas

// App-defined icon mapping - framework doesn't handle UI concerns
private let shapeItems: [(tool: DrawingTool, icon: String, name: String)] = [
    (.rectangle, "rectangle", "Rectangle"),
    (.oval, "circle", "Oval"),
    (.triangle, "triangle", "Triangle"),
    (.diamond, "diamond", "Diamond"),
    (.star, "star", "Star"),
]

/// Inline shape picker strip shown in the sub-toolbar when a shape tool is active.
struct ShapePickerStrip: View {
    @ObservedObject var viewModel: CanvasViewModel
    @Binding var lastShapeTool: DrawingTool

    var body: some View {
        HStack(spacing: 2) {
            ForEach(shapeItems, id: \.tool) { item in
                Button(action: {
                    viewModel.selectedTool = item.tool
                    lastShapeTool = item.tool
                }) {
                    ShapeItemCell(
                        item: item,
                        isSelected: viewModel.selectedTool == item.tool
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Individual cell

private struct ShapeItemCell: View {
    let item: (tool: DrawingTool, icon: String, name: String)
    let isSelected: Bool

    var body: some View {
        Image(systemName: item.icon)
            .font(.system(size: 14))
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .accessibilityLabel(Text(item.name))
            .tooltip(item.name)
    }
}
