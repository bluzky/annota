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
        let end = shiftHeld ? constrainLineToAngle(from: start, to: current) : current

        guard let mockLine = makeLine(from: start, to: end, viewModel: viewModel) else {
            return AnyView(EmptyView())
        }

        return AnyView(
            LineObjectView(object: mockLine, isSelected: false, viewModel: viewModel)
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
        guard let line = makeLine(from: start, to: finalEnd, viewModel: viewModel) else { return }
        viewModel.addObject(line)
    }

    // MARK: - Private Helpers

    private func makeLine(
        from start: CGPoint,
        to end: CGPoint,
        viewModel: CanvasViewModel
    ) -> LineObject? {
        let length = hypot(end.x - start.x, end.y - start.y)
        guard length > 3 else { return nil }
        return LineObject(
            startPoint: start,
            endPoint: end,
            strokeColor: viewModel.activeColor
        )
    }
}
