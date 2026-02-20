//
//  ShapePickerView.swift
//  texttool
//

import SwiftUI

/// A popover panel showing a grid of shape preset thumbnails.
/// Selecting a preset activates `.shape(preset)` on the view model.
struct ShapePickerView: View {
    @ObservedObject var viewModel: CanvasViewModel
    @Binding var isPresented: Bool

    private let columns = [
        GridItem(.fixed(72), spacing: 8),
        GridItem(.fixed(72), spacing: 8),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(ShapePreset.builtIn, id: \.name) { preset in
                ShapePresetCell(
                    preset: preset,
                    isSelected: viewModel.selectedTool == .shape(preset)
                )
                .onTapGesture {
                    viewModel.selectedTool = .shape(preset)
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

private struct ShapePresetCell: View {
    let preset: ShapePreset
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                let rect = CGRect(origin: .zero, size: geo.size)
                ZStack {
                    // Fill
                    preset.path(in: rect)
                        .fill(Color.accentColor.opacity(isSelected ? 0.25 : 0.08))

                    // Stroke
                    preset.path(in: rect)
                        .stroke(
                            isSelected ? Color.accentColor : Color.secondary,
                            lineWidth: isSelected ? 2 : 1.5
                        )
                }
            }
            .frame(width: 44, height: 36)

            Text(preset.name)
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
