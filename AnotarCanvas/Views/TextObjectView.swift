//
//  TextObjectView.swift
//  AnotarCanvas
//
//  Created by Flex on 12/11/25.
//

import SwiftUI

struct TextObjectView: View {
    let object: TextObject
    @ObservedObject var viewModel: CanvasViewModel
    @FocusState private var isFocused: Bool
    var isSelected: Bool = false

    private var scale: CGFloat { viewModel.viewport.scale }

    /// Returns a font scaled for the current viewport zoom level
    private var scaledFont: Font {
        var font: Font
        let scaledSize = object.fontSize * scale

        if object.textAttributes.fontFamily == "System" {
            font = .system(size: scaledSize, weight: object.textAttributes.fontWeight.swiftUIWeight)
        } else {
            font = .custom(object.textAttributes.fontFamily, size: scaledSize)
        }

        if object.textAttributes.isItalic {
            font = font.italic()
        }

        return font
    }

    var body: some View {
        Group {
            if object.isEditing {
                AutoGrowingTextView(
                    text: binding,
                    fontSize: object.fontSize * scale,
                    fontFamily: object.textAttributes.fontFamily,
                    textColor: object.color,
                    alignment: object.textAttributes.horizontalAlignment.nsAlignment,
                    onFocus: { isFocused = true },
                    onSizeChange: { size in
                        let unscaled = CGSize(width: size.width / scale, height: size.height / scale)
                        viewModel.updateObject(withId: object.id, as: TextObject.self) { $0.size = unscaled }
                        // Do NOT set width here — typing must not lock the width
                    },
                    scale: scale,
                    maxWidth: object.width.map { $0 * scale }
                )
                .id(object.id) // Keep same view instance while editing
                .background(Color.white.opacity(0.95))
                .cornerRadius(4 * scale)
                .overlay(
                    RoundedRectangle(cornerRadius: 4 * scale)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 2.0)
                )
                .scaleEffect(1.0 / scale, anchor: .topLeading)
            } else {
                let textContent = Text(object.text.isEmpty ? "Text" : object.text)
                    .font(scaledFont)
                    .foregroundColor(object.text.isEmpty ? object.color.opacity(0.5) : object.color)
                    .multilineTextAlignment(object.textAttributes.horizontalAlignment.swiftUIAlignment)
                    .padding(4 * scale)
                    .background(
                        RoundedRectangle(cornerRadius: 4 * scale)
                            .fill(Color.white.opacity(0.01))
                    )
                    .scaleEffect(1.0 / scale, anchor: .topLeading)
                if let w = object.width {
                    textContent
                        .frame(maxWidth: w * scale, alignment: .topLeading)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    textContent
                        .fixedSize()
                }
            }
        }
        .rotationEffect(.radians(object.rotation))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .offset(x: object.position.x, y: object.position.y)
    }

    private var binding: Binding<String> {
        Binding(
            get: { object.text },
            set: { viewModel.updateText(objectId: object.id, text: $0) }
        )
    }
}
