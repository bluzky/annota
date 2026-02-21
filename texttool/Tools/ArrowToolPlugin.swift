//
//  ArrowToolPlugin.swift
//  texttool
//

import SwiftUI

/// Tool plugin for creating arrows via drag-to-create gesture.
/// Renders preview with arrowhead; creates LineObject with endArrowHead = .open.
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
        let end = shiftHeld ? constrainLineToAngle(from: start, to: current) : current

        guard let mockArrow = makeArrow(from: start, to: end, viewModel: viewModel) else {
            return AnyView(EmptyView())
        }

        return AnyView(
            LineObjectView(object: mockArrow, isSelected: false, viewModel: viewModel)
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
        let finalEnd = shiftHeld ? constrainLineToAngle(from: start, to: end) : end
        guard let arrow = makeArrow(from: start, to: finalEnd, viewModel: viewModel) else { return }
        viewModel.addObject(arrow)
    }

    // MARK: - Private Helpers

    private func makeArrow(
        from start: CGPoint,
        to end: CGPoint,
        viewModel: CanvasViewModel
    ) -> LineObject? {
        let length = hypot(end.x - start.x, end.y - start.y)
        guard length > 3 else { return nil }
        return LineObject(
            startPoint: start,
            endPoint: end,
            strokeColor: viewModel.activeColor,
            endArrowHead: .open
        )
    }
}
