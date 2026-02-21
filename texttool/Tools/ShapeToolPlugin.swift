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
        if case .shape = tool { return true }
        return false
    }

    func renderPreview(
        start: CGPoint,
        current: CGPoint,
        viewModel: CanvasViewModel
    ) -> AnyView {
        guard case .shape(let preset) = viewModel.selectedTool else {
            return AnyView(EmptyView())
        }

        let shiftHeld = NSEvent.modifierFlags.contains(.shift)
        let end = clampedEnd(start: start, current: current, shiftHeld: shiftHeld)

        guard let mockObject = makeShape(preset: preset, from: start, to: end, viewModel: viewModel) else {
            return AnyView(EmptyView())
        }

        return AnyView(
            ShapeObjectView(object: mockObject, isSelected: false, viewModel: viewModel)
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
        guard case .shape(let preset) = viewModel.selectedTool else { return }
        let finalEnd = clampedEnd(start: start, current: end, shiftHeld: shiftHeld)
        guard let shape = makeShape(preset: preset, from: start, to: finalEnd, viewModel: viewModel) else { return }
        viewModel.addObject(shape)
    }

    // MARK: - Private Helpers

    private func makeShape(
        preset: ShapePreset,
        from start: CGPoint,
        to end: CGPoint,
        viewModel: CanvasViewModel
    ) -> ShapeObject? {
        let origin = CGPoint(x: min(start.x, end.x), y: min(start.y, end.y))
        let size = CGSize(width: abs(end.x - start.x), height: abs(end.y - start.y))
        guard size.width > 1 && size.height > 1 else { return nil }
        return ShapeObject(
            position: origin,
            size: size,
            preset: preset,
            color: viewModel.activeColor,
            autoResizeHeight: viewModel.autoResizeShapes
        )
    }

    private func clampedEnd(start: CGPoint, current: CGPoint, shiftHeld: Bool) -> CGPoint {
        guard shiftHeld else { return current }
        let side = max(abs(current.x - start.x), abs(current.y - start.y))
        return CGPoint(
            x: start.x + (current.x >= start.x ? side : -side),
            y: start.y + (current.y >= start.y ? side : -side)
        )
    }
}
