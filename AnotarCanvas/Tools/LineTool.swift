//
//  LineTool.swift
//  AnotarCanvas
//

import SwiftUI
import AppKit

public extension DrawingTool {
    public static let line = DrawingTool(id: "line")
}

/// Tool for creating lines via drag-to-create gesture.
/// Supports shift+drag for 15-degree angle snapping.
public struct LineTool: CanvasTool {
    public let toolType: DrawingTool = .line

    public let name: String = "Line"
    public let category: ToolCategory = .drawing
    public let cursor: NSCursor = .crosshair

    /// Line supports stroke and label text
    public var capabilities: Set<ToolCapability> {
        [.stroke, .labelText]
    }

    // MARK: - Manifest

    public static let manifest = ToolManifest(
        tool: LineTool(),
        discriminator: "line",
        interactiveView: { obj, isSelected, vm in
            AnyView(LineObjectView(object: obj, isSelected: isSelected, viewModel: vm))
        },
        exportView: { obj in
            AnyView(ExportLineObjectView(object: obj))
        }
    )

    public func renderPreview(
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

    public func handleDragChanged(
        start: CGPoint,
        current: CGPoint,
        viewModel: CanvasViewModel
    ) {
        if viewModel.dragStartPoint == nil {
            viewModel.dragStartPoint = start
        }
        viewModel.currentDragPoint = current
    }

    public func handleDragEnded(
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

        // Get stored tool attributes
        let attrs = viewModel.currentToolAttributes

        let strokeColor = attrs["strokeColor"] as? Color ?? .black
        let strokeWidth = attrs["strokeWidth"] as? CGFloat ?? 2.0
        let strokeStyle = attrs["strokeStyle"] as? StrokeStyleType ?? .solid

        return LineObject(
            startPoint: start,
            endPoint: end,
            strokeColor: strokeColor,
            strokeWidth: strokeWidth,
            strokeStyle: strokeStyle
        )
    }
}
