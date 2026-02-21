//
//  ArrowToolPlugin.swift
//  texttool
//

import SwiftUI

/// Tool plugin for creating arrows via drag-to-create gesture.
/// Renders preview with arrowhead; creates LineObject with endArrowHead.
struct ArrowToolPlugin: CanvasTool {
    let id = "arrow-tool"
    let toolType: DrawingTool = .arrow

    var metadata: ToolMetadata {
        ToolMetadata(
            name: "Arrow",
            icon: "arrow.right",
            category: .drawing,
            cursorType: .crosshair,
            shortcutKey: "A"
        )
    }

    func renderPreview(
        start: CGPoint,
        current: CGPoint,
        viewModel: CanvasViewModel
    ) -> AnyView {
        let shiftHeld = NSEvent.modifierFlags.contains(.shift)
        let end = shiftHeld ? constrainToAngle(from: start, to: current) : current
        let angle = atan2(end.y - start.y, end.x - start.x)
        let headLength: CGFloat = 14

        return AnyView(
            ZStack {
                // Line
                Path { path in
                    path.move(to: start)
                    path.addLine(to: end)
                }
                .stroke(viewModel.activeColor.opacity(0.5), lineWidth: 2)

                // Arrow head (open V)
                Path { path in
                    path.move(to: CGPoint(
                        x: end.x - headLength * cos(angle - .pi / 6),
                        y: end.y - headLength * sin(angle - .pi / 6)
                    ))
                    path.addLine(to: end)
                    path.addLine(to: CGPoint(
                        x: end.x - headLength * cos(angle + .pi / 6),
                        y: end.y - headLength * sin(angle + .pi / 6)
                    ))
                }
                .stroke(viewModel.activeColor.opacity(0.5), lineWidth: 2)
            }
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
        viewModel.addLine(from: start, to: finalEnd, asArrow: true)
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
