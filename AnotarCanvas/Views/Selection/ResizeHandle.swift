//
//  ResizeHandle.swift
//  AnotarCanvas
//
//  Created by Claude on 2/18/26.
//

import SwiftUI

/// A resize handle displayed at corners or edges of the selection box
struct ResizeHandle: View {
    let size: CGFloat

    var style: HandleStyle = .standard

    enum HandleStyle {
        case standard    // White fill with blue border
        case highlighted // Filled blue (when hovering)
    }

    init(size: CGFloat = SelectionBox.handleSize, style: HandleStyle = .standard) {
        self.size = size
        self.style = style
    }

    var body: some View {
        Circle()
            .fill(fillColor)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(strokeColor, lineWidth: 1)
            )
    }

    private var fillColor: Color {
        switch style {
        case .standard:
            return .white
        case .highlighted:
            return Color.blue.opacity(0.3)
        }
    }

    private var strokeColor: Color {
        .blue
    }
}

#Preview {
    HStack(spacing: 20) {
        VStack {
            ResizeHandle()
            Text("Standard")
        }
        VStack {
            ResizeHandle(style: .highlighted)
            Text("Highlighted")
        }
    }
    .padding()
}
