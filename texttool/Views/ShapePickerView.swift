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

    private let columns = [
        GridItem(.fixed(72), spacing: 8),
        GridItem(.fixed(72), spacing: 8),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
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
        .padding(12)
        // Width = 2 columns × 72 + 1 gap × 8 + 2 × 12 padding
        .frame(width: 176)
    }
}

// MARK: - Individual cell

private struct ShapeItemCell: View {
    let item: (tool: DrawingTool, icon: String, name: String)
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: item.icon)
                .font(.system(size: 24))
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .frame(width: 44, height: 36)

            Text(item.name)
                .font(.system(size: 10))
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(width: 72, height: 64)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}
