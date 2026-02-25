//
//  ColorPresetPicker.swift
//  Annota
//
//  A tldraw-inspired color preset picker shown as a popover grid of color circles.
//

import SwiftUI

// Row 1: lighter colors + white
private let lightPresets: [(name: String, color: Color)] = [
    ("Grey", Color(hex: 0x9FA8B2)),
    ("Light Red", Color(hex: 0xF87777)),
    ("Yellow", Color(hex: 0xF1AC4B)),
    ("Light Green", Color(hex: 0x4CB05E)),
    ("Light Blue", Color(hex: 0x4BA1F1)),
    ("Light Violet", Color(hex: 0xE085F4)),
    ("White", Color(hex: 0xFFFFFF)),
]

// Row 2: darker colors + custom
private let darkPresets: [(name: String, color: Color)] = [
    ("Black", Color(hex: 0x1D1D1D)),
    ("Red", Color(hex: 0xE03131)),
    ("Orange", Color(hex: 0xE16919)),
    ("Green", Color(hex: 0x099268)),
    ("Blue", Color(hex: 0x4465E9)),
    ("Violet", Color(hex: 0xAE3EC9)),
]

// MARK: - Color hex initializer

private extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Color Preset Picker

/// A button that shows the current color and opens a popover with preset color swatches.
struct ColorPresetPicker: View {
    @Binding var selection: Color
    var onChange: ((Color) -> Void)? = nil

    @State private var showPopover = false

    var body: some View {
        Button(action: { showPopover.toggle() }) {
            Circle()
                .fill(selection)
                .frame(width: 22, height: 22)
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            ColorPresetGrid(
                selection: $selection,
                isPresented: $showPopover,
                onChange: onChange
            )
        }
    }
}

// MARK: - Popover Grid

private struct ColorPresetGrid: View {
    @Binding var selection: Color
    @Binding var isPresented: Bool
    var onChange: ((Color) -> Void)?

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                ForEach(lightPresets, id: \.name) { preset in
                    ColorCircleCell(
                        color: preset.color,
                        name: preset.name
                    ) {
                        selectColor(preset.color)
                    }
                }
            }
            HStack(spacing: 4) {
                ForEach(darkPresets, id: \.name) { preset in
                    ColorCircleCell(
                        color: preset.color,
                        name: preset.name
                    ) {
                        selectColor(preset.color)
                    }
                }
                // Custom color button
                CustomColorButton(selection: $selection, onChange: onChange)
            }
        }
        .padding(6)
    }

    private func selectColor(_ color: Color) {
        selection = color
        onChange?(color)
        // Dismiss on next run loop tick so it's a separate transaction —
        // the popover teardown won't block the color update.
        DispatchQueue.main.async {
            isPresented = false
        }
    }
}

// MARK: - Color Circle Cell

private struct ColorCircleCell: View {
    let color: Color
    let name: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Circle()
                .fill(color)
                .frame(width: 22, height: 22)
                .overlay(
                    Circle()
                        .stroke(borderColor, lineWidth: 1)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(name))
    }

    private var borderColor: Color {
        // White/light colors need a visible border; dark colors get a subtle one
        color.luminance > 0.85 ? Color.gray.opacity(0.4) : Color.white.opacity(0.2)
    }
}

// MARK: - Custom Color Button

private struct CustomColorButton: View {
    /// Minimal opacity to keep ColorPicker interactive while visually hidden.
    /// Fully invisible (opacity 0.0) breaks macOS ColorPicker interactivity.
    private static let hiddenButInteractiveOpacity = 0.015

    @Binding var selection: Color
    var onChange: ((Color) -> Void)?

    var body: some View {
        ZStack {
            // Hidden native ColorPicker positioned behind the circle
            ColorPicker("", selection: Binding(
                get: { selection },
                set: {
                    selection = $0
                    onChange?($0)
                }
            ))
            .labelsHidden()
            .opacity(Self.hiddenButInteractiveOpacity)

            // Visual "+" circle overlay (non-interactive, lets clicks through)
            Circle()
                .fill(Color(nsColor: .controlBackgroundColor))
                .frame(width: 22, height: 22)
                .overlay(
                    Circle()
                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                )
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                )
                .allowsHitTesting(false)
        }
        .frame(width: 22, height: 22)
    }
}

// MARK: - Color helpers

private extension Color {
    /// Approximate luminance for border contrast decisions.
    var luminance: Double {
        guard let components = NSColor(self).usingColorSpace(.sRGB) else { return 0.5 }
        let r = components.redComponent
        let g = components.greenComponent
        let b = components.blueComponent
        return 0.299 * r + 0.587 * g + 0.114 * b
    }

}
