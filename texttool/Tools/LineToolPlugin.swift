//
//  LineToolPlugin.swift
//  texttool
//

import SwiftUI

/// Tool plugin for creating lines via drag-to-create gesture.
/// Supports shift+drag for 15-degree angle snapping.
struct LineToolPlugin: CanvasTool {
    let id = "line-tool"
    let toolType: DrawingTool = .line

    var metadata: ToolMetadata {
        ToolMetadata(
            name: "Line",
            icon: "line.diagonal",
            category: .drawing,
            cursorType: .crosshair,
            shortcutKey: "L"
        )
    }

    func renderPreview(
        start: CGPoint,
        current: CGPoint,
        viewModel: CanvasViewModel
    ) -> AnyView {
        let shiftHeld = NSEvent.modifierFlags.contains(.shift)
        let end = shiftHeld ? constrainToAngle(from: start, to: current) : current

        return AnyView(
            Path { path in
                path.move(to: start)
                path.addLine(to: end)
            }
            .stroke(viewModel.activeColor.opacity(0.5), lineWidth: 2)
        )
    }

    func handleDragChanged(
        start: CGPoint,
        current: CGPoint,
        viewModel: CanvasViewModel
    ) {
        if viewModel.dragStartPoint == nil {
            viewModel.dragStartPoint = start
        }
        viewModel.currentDragPoint = current
    }

    func handleDragEnded(
        start: CGPoint,
        end: CGPoint,
        viewModel: CanvasViewModel,
        shiftHeld: Bool
    ) {
        let finalEnd = shiftHeld ? constrainToAngle(from: start, to: end) : end
        viewModel.addLine(from: start, to: finalEnd, asArrow: false)
    }

    private func constrainToAngle(from start: CGPoint, to end: CGPoint) -> CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let distance = hypot(dx, dy)
        let angle = atan2(dy, dx)
        let snapAngle = CGFloat.pi / 12
        let snappedAngle = (angle / snapAngle).rounded() * snapAngle
        return CGPoint(
            x: start.x + distance * cos(snappedAngle),
            y: start.y + distance * sin(snappedAngle)
        )
    }
}
