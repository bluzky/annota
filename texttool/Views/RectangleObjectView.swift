//
//  RectangleObjectView.swift
//  texttool
//
//  Created by Flex on 12/11/25.
//

import SwiftUI
import AppKit

struct RectangleObjectView: View {
    let object: RectangleObject
    var isSelected: Bool = false
    @ObservedObject var viewModel: CanvasViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            // Rectangle shape
            Rectangle()
                .stroke(object.color, lineWidth: 2)
                .background(object.color.opacity(0.1))
                .frame(width: object.size.width, height: effectiveHeight)

            // Text content (centered inside rectangle)
            if object.isEditing {
                ConstrainedAutoGrowingTextView(
                    text: binding,
                    fontSize: 16,
                    textColor: .black,
                    maxWidth: object.size.width - 16,
                    alignment: .center,
                    onHeightChange: { newHeight in
                        if object.autoResizeHeight {
                            updateHeightIfNeeded(newHeight + 24)
                        }
                    }
                )
                .frame(width: object.size.width - 16)
                .padding(8)
            } else if !object.text.isEmpty {
                Text(object.text)
                    .font(.system(size: 16))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .frame(width: object.size.width - 16)
                    .padding(8)
            }

        }
        .rotationEffect(.radians(object.rotation))
        .position(
            x: object.position.x + object.size.width / 2,
            y: object.position.y + effectiveHeight / 2
        )
        .onChange(of: object.text) { _ in
            if object.autoResizeHeight {
                updateHeight()
            }
        }
    }

    private var effectiveHeight: CGFloat {
        if object.autoResizeHeight && !object.text.isEmpty {
            return max(object.size.height, calculatedTextHeight + 24)
        }
        return object.size.height
    }

    private var calculatedTextHeight: CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16)
        ]
        let attributedString = NSAttributedString(string: object.text, attributes: attributes)
        let boundingRect = attributedString.boundingRect(
            with: NSSize(width: object.size.width - 32, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        return ceil(boundingRect.height)
    }

    private func updateHeight() {
        let newHeight = calculatedTextHeight + 24
        if newHeight > object.size.height {
            viewModel.updateRectangleObject(withId: object.id) { rect in
                rect.size.height = newHeight
            }
        }
    }

    private func updateHeightIfNeeded(_ newHeight: CGFloat) {
        if newHeight > object.size.height {
            viewModel.updateRectangleObject(withId: object.id) { rect in
                rect.size.height = newHeight
            }
        }
    }

    private var binding: Binding<String> {
        Binding(
            get: { object.text },
            set: { viewModel.updateText(objectId: object.id, text: $0) }
        )
    }
}
