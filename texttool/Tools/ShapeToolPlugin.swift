//
//  ShapeToolPlugin.swift
//  texttool
//

import SwiftUI

/// Tool plugin for creating shapes via drag-to-create gesture.
/// Handles all ShapePreset types (rectangle, oval, triangle, etc.)
struct ShapeToolPlugin: CanvasTool {
    let id = "shape-tool"
    let toolType: DrawingTool = .shape(.rectangle)

    var metadata: ToolMetadata {
        ToolMetadata(
            name: "Shape",
            icon: "square.on.square",
            category: .shape,
            cursorType: .crosshair,
            shortcutKey: "R"
        )
    }

    /// Matches any .shape(_) DrawingTool variant
    func matches(_ tool: DrawingTool) -> Bool {
        tool.isShapeTool
    }

    func renderPreview(
        start: CGPoint,
        current: CGPoint,
        viewModel: CanvasViewModel
    ) -> AnyView {
        guard let preset = viewModel.selectedTool.shapePreset else {
            return AnyView(EmptyView())
        }

        let shiftHeld = NSEvent.modifierFlags.contains(.shift)
        let rawWidth = abs(current.x - start.x)
        let rawHeight = abs(current.y - start.y)
        let width = shiftHeld ? max(rawWidth, rawHeight) : rawWidth
        let height = shiftHeld ? max(rawWidth, rawHeight) : rawHeight
        let x = min(start.x, current.x) + width / 2
        let y = min(start.y, current.y) + height / 2
        let previewRect = CGRect(origin: .zero, size: CGSize(width: width, height: height))

        return AnyView(
            preset.path(in: previewRect)
                .stroke(viewModel.activeColor.opacity(0.5), lineWidth: 2)
                .frame(width: width, height: height)
                .position(x: x, y: y)
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
        guard let preset = viewModel.selectedTool.shapePreset else { return }

        let finalEnd: CGPoint
        if shiftHeld {
            let rawWidth = abs(end.x - start.x)
            let rawHeight = abs(end.y - start.y)
            let side = max(rawWidth, rawHeight)
            finalEnd = CGPoint(
                x: start.x + (end.x >= start.x ? side : -side),
                y: start.y + (end.y >= start.y ? side : -side)
            )
        } else {
            finalEnd = end
        }

        viewModel.addShape(preset: preset, from: start, to: finalEnd)
    }
}
