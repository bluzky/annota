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

    var body: some View {
        Group {
            if object.isEditing {
                AutoGrowingTextView(
                    text: binding,
                    fontSize: object.fontSize,
                    fontFamily: object.textAttributes.fontFamily,
                    textColor: object.color,
                    onFocus: { isFocused = true },
                    onSizeChange: { size in
                        viewModel.updateObject(withId: object.id, as: TextObject.self) { $0.size = size }
                    }
                )
                .id(object.id) // Keep same view instance while editing
                .background(Color.white.opacity(0.95))
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
            } else {
                Text(object.text.isEmpty ? "Text" : object.text)
                    .font(object.textAttributes.font)
                    .foregroundColor(object.text.isEmpty ? object.color.opacity(0.5) : object.color)
                    .fixedSize()
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.01))
                    )
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
