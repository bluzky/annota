//
//  SelectionBoxView.swift
//  texttool
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
    private let rotationHandleSize: CGFloat = SelectionBox.rotationHandleSize
    private let selectionColor: Color = .blue

    var body: some View {
        ZStack {
            // Selection border rectangle
            Rectangle()
                .stroke(selectionColor, lineWidth: 1)
                .frame(
                    width: selectionBox.bounds.width,
                    height: selectionBox.bounds.height
                )

            // Corner handles: larger rotation square with small resize square at its inner corner
            ForEach(Corner.allCases, id: \.self) { corner in
                // Rotation handle (larger square, offset outward from corner)
                if selectionBox.isSingleSelection {
                    let shift = (rotationHandleSize - handleSize) / 2
                    Rectangle()
                        .fill(Color.white.opacity(0.01))
                        .frame(width: rotationHandleSize, height: rotationHandleSize)
                        .overlay(
                            Rectangle()
                                .stroke(selectionColor.opacity(0.4), lineWidth: 1)
                        )
                        .position(rotationSquarePosition(for: corner, shift: shift))
                }

                // Resize handle (small square, at the actual corner)
                ResizeHandle(size: handleSize)
                    .position(relativePosition(for: selectionBox.cornerPosition(for: corner)))
            }

            // Edge resize handles (only for single selection) — span between corners
            if selectionBox.isSingleSelection {
                ForEach(Edge.allCases, id: \.self) { edge in
                    edgeHandle(for: edge)
                }
            }
        }
        .frame(
            width: selectionBox.bounds.width + rotationHandleSize,
            height: selectionBox.bounds.height + rotationHandleSize
        )
        .allowsHitTesting(false) // All interaction handled by CanvasView gestures
        .rotationEffect(.radians(selectionBox.isSingleSelection ? selectionBox.rotation : 0))
        .position(x: selectionBox.center.x, y: selectionBox.center.y)
    }

    private func relativePosition(for absolutePosition: CGPoint) -> CGPoint {
        let offset = rotationHandleSize / 2
        return CGPoint(
            x: absolutePosition.x - selectionBox.bounds.minX + offset,
            y: absolutePosition.y - selectionBox.bounds.minY + offset
        )
    }

    /// Edge handle that spans between two corner handles
    @ViewBuilder
    private func edgeHandle(for edge: Edge) -> some View {
        let w = selectionBox.bounds.width
        let h = selectionBox.bounds.height

        switch edge {
        case .top, .bottom:
            let barWidth = max(w - handleSize * 2, 0)
            Rectangle()
                .fill(Color.white.opacity(0.4))
                .frame(width: barWidth, height: handleSize)
                .overlay(
                    Rectangle()
                        .stroke(selectionColor.opacity(0.4), lineWidth: 1)
                )
                .position(relativePosition(for: selectionBox.edgePosition(for: edge)))
        case .left, .right:
            let barHeight = max(h - handleSize * 2, 0)
            Rectangle()
                .fill(Color.white.opacity(0.4))
                .frame(width: handleSize, height: barHeight)
                .overlay(
                    Rectangle()
                        .stroke(selectionColor.opacity(0.4), lineWidth: 1)
                )
                .position(relativePosition(for: selectionBox.edgePosition(for: edge)))
        }
    }

    /// Position for the larger rotation square, shifted outward so the resize handle sits at its inner corner
    private func rotationSquarePosition(for corner: Corner, shift: CGFloat) -> CGPoint {
        let cornerPos = relativePosition(for: selectionBox.cornerPosition(for: corner))
        switch corner {
        case .topLeft:
            return CGPoint(x: cornerPos.x - shift, y: cornerPos.y - shift)
        case .topRight:
            return CGPoint(x: cornerPos.x + shift, y: cornerPos.y - shift)
        case .bottomLeft:
            return CGPoint(x: cornerPos.x - shift, y: cornerPos.y + shift)
        case .bottomRight:
            return CGPoint(x: cornerPos.x + shift, y: cornerPos.y + shift)
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.2)

        let sampleBox = SelectionBox(
            bounds: CGRect(x: 100, y: 100, width: 200, height: 150),
            individualBounds: [:],
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
