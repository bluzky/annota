//
//  SelectionBoxView.swift
//  AnotarCanvas
//
//  Created by Claude on 2/18/26.
//

import SwiftUI

/// Visual representation of the selection box around selected objects.
/// Cursor changes and resize interactions are handled by CanvasView's gesture system.
struct SelectionBoxView: View {
    let selectionBox: SelectionBox
    @ObservedObject var viewModel: CanvasViewModel

    private let handleSize: CGFloat = SelectionBox.handleSize
    private let selectionColor: Color = .blue

    var body: some View {
        ZStack {
            // Selection border rectangle
            Rectangle()
                .stroke(selectionColor, lineWidth: 2)
                .frame(
                    width: selectionBox.bounds.width,
                    height: selectionBox.bounds.height
                )

            // Corner resize handles only (small squares at corners)
            ForEach(Corner.allCases, id: \.self) { corner in
                ResizeHandle(size: handleSize)
                    .position(relativePosition(for: selectionBox.cornerPosition(for: corner)))
            }
        }
        .frame(
            width: selectionBox.bounds.width + handleSize,
            height: selectionBox.bounds.height + handleSize
        )
        .allowsHitTesting(false) // All interaction handled by CanvasView gestures
        .rotationEffect(.radians(selectionBox.isSingleSelection ? selectionBox.rotation : 0))
        .position(x: selectionBox.center.x, y: selectionBox.center.y)
    }

    private func relativePosition(for absolutePosition: CGPoint) -> CGPoint {
        let offset = handleSize / 2
        return CGPoint(
            x: absolutePosition.x - selectionBox.bounds.minX + offset,
            y: absolutePosition.y - selectionBox.bounds.minY + offset
        )
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.2)

        let sampleBox = SelectionBox(
            bounds: CGRect(x: 100, y: 100, width: 200, height: 150),
            isSingleSelection: true,
            rotation: 0
        )

        SelectionBoxView(
            selectionBox: sampleBox,
            viewModel: CanvasViewModel()
        )
    }
    .frame(width: 400, height: 400)
}
