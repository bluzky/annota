//
//  ShapePickerView.swift
//  texttool
//

import SwiftUI
import AnotarCanvas

/// A popover panel showing a grid of shape thumbnails.
/// Selecting a shape activates the corresponding DrawingTool on the view model.
struct ShapePickerView: View {
    @ObservedObject var viewModel: CanvasViewModel
    @Binding var isPresented: Bool

    // App-defined icon mapping - framework doesn't handle UI concerns
    private let shapeItems: [(tool: DrawingTool, icon: String, name: String)] = [
        (.rectangle, "rectangle", "Rectangle"),
        (.oval, "circle", "Oval"),
        (.triangle, "triangle", "Triangle"),
        (.diamond, "diamond", "Diamond"),
        (.star, "star", "Star"),
    ]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(shapeItems, id: \.tool) { item in
                ShapeItemCell(
                    item: item,
                    isSelected: viewModel.selectedTool == item.tool
                )
                .onTapGesture {
                    viewModel.selectedTool = item.tool
                    isPresented = false
                }
            }
        }
        .padding(4)
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
            .help(item.name)
    }
}
