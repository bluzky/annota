//
//  ShapeObjectView.swift
//  AnotarCanvas
//

import SwiftUI
import AppKit

struct ShapeObjectView: View {
    let object: ShapeObject
    var isSelected: Bool = false
    @ObservedObject var viewModel: CanvasViewModel

    var body: some View {
        ZStack {
            let shapeRect = CGRect(origin: .zero, size: CGSize(width: object.size.width, height: effectiveHeight))
            // Shape fill + stroke — both framed identically so they overlap exactly
            object.path(in: shapeRect)
                .fill(object.fillColor.opacity(object.fillOpacity))
                .frame(width: object.size.width, height: effectiveHeight)
            object.path(in: shapeRect)
                .stroke(object.strokeColor, lineWidth: object.strokeWidth)
                .frame(width: object.size.width, height: effectiveHeight)

            // Text content (centered inside shape)
            if object.isEditing {
                ConstrainedAutoGrowingTextView(
                    text: binding,
                    fontSize: object.textAttributes.fontSize,
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
        .onChange(of: object.text) { _, _ in
            if object.autoResizeHeight {
                updateHeight()
            }
        }
    }

    // MARK: - Height Helpers

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
            viewModel.updateObject(withId: object.id, as: ShapeObject.self) { shape in
                shape.size.height = newHeight
            }
        }
    }

    private func updateHeightIfNeeded(_ newHeight: CGFloat) {
        if newHeight > object.size.height {
            viewModel.updateObject(withId: object.id, as: ShapeObject.self) { shape in
                shape.size.height = newHeight
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
