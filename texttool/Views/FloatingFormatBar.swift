//
//  FloatingFormatBar.swift
//  texttool
//
//  Created by Flex on 12/11/25.
//

import SwiftUI
import AppKit

struct FloatingFormatBar: View {
    var position: CGPoint
    var currentAttributes: TextAttributes
    var onFontSizeChange: (CGFloat) -> Void
    var onBoldToggle: () -> Void
    var onItalicToggle: () -> Void
    var onColorChange: (Color) -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Font Size Picker
            Picker("", selection: Binding(
                get: { currentAttributes.fontSize },
                set: { onFontSizeChange($0) }
            )) {
                ForEach([12, 14, 16, 18, 24, 36, 48, 72], id: \.self) { size in
                    Text("\(Int(size))").tag(CGFloat(size))
                }
            }
            .labelsHidden()
            .frame(width: 70)

            Divider()
                .frame(height: 20)

            // Bold Button
            Button(action: onBoldToggle) {
                Text("B")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(currentAttributes.isBold ? .white : .primary)
                    .frame(width: 28, height: 28)
                    .background(currentAttributes.isBold ? Color.blue : Color.clear)
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)

            // Italic Button
            Button(action: onItalicToggle) {
                Text("I")
                    .font(.system(size: 14).italic())
                    .foregroundColor(currentAttributes.isItalic ? .white : .primary)
                    .frame(width: 28, height: 28)
                    .background(currentAttributes.isItalic ? Color.blue : Color.clear)
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)

            Divider()
                .frame(height: 20)

            // Color Picker
            ColorPicker("", selection: Binding(
                get: { currentAttributes.textColor },
                set: { onColorChange($0) }
            ))
            .labelsHidden()
            .frame(width: 40)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
        .position(x: position.x, y: position.y - 50)
    }
}

struct TextAttributes {
    var fontSize: CGFloat
    var isBold: Bool
    var isItalic: Bool
    var textColor: Color

    static var `default`: TextAttributes {
        TextAttributes(fontSize: 16, isBold: false, isItalic: false, textColor: .black)
    }
}
