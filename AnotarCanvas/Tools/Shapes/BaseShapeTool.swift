//
//  BaseShapeTool.swift
//  AnotarCanvas
//
//  Base class for all shape tools. Each shape tool defines its own SVG path geometry.
//  Subclasses only need to override `svgPath`, `toolType`, and `name`.
//

import SwiftUI
import AppKit

/// Base class for all shape tools. Each shape tool defines its own SVG path geometry.
/// Subclasses only need to override `svgPath`, `toolType`, and `name`.
open class ShapeTool: CanvasTool {

    public init() {}

    /// The SVG path defining the shape's geometry (must be overridden by subclasses)
    open var svgPath: String {
        fatalError("Subclasses must override svgPath")
    }

    /// Tool name (must be overridden by subclasses)
    open var name: String {
        fatalError("Subclasses must override name")
    }

    /// Category is always .shape for shape tools
    open var category: ToolCategory {
        .shape
    }

    /// Cursor type — defaults to crosshair for all shape tools
    open var cursor: NSCursor { .crosshair }

    /// The DrawingTool type identifying this tool
    open var toolType: DrawingTool {
        fatalError("Subclasses must override toolType")
    }

    /// Shapes support stroke, fill, and shape-specific attributes (no label text)
    open var capabilities: Set<ToolCapability> {
        [.stroke, .fill, .shapeAttributes]
    }

    // MARK: - Preview Rendering

    public func renderPreview(
        start: CGPoint,
        current: CGPoint,
        viewModel: CanvasViewModel
    ) -> AnyView {
        let shiftHeld = NSEvent.modifierFlags.contains(.shift)
        let end = clampedEnd(start: start, current: current, shiftHeld: shiftHeld)

        guard let mockObject = makeShape(from: start, to: end, viewModel: viewModel) else {
            return AnyView(EmptyView())
        }

        return AnyView(
            ShapeObjectView(object: mockObject, isSelected: false, viewModel: viewModel)
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
        let finalEnd = clampedEnd(start: start, current: end, shiftHeld: shiftHeld)
        guard let shape = makeShape(from: start, to: finalEnd, viewModel: viewModel) else { return }
        viewModel.addObject(shape)
    }

    /// Returns the tool manifest for this shape tool.
    /// All shape tools produce ShapeObject, so the view and codable registrations
    /// are identical for every tool — only the tool instance differs.
    public func manifest() -> ToolManifest<ShapeObject> {
        ToolManifest(
            tool: self,
            discriminator: "shape",
            interactiveView: { obj, isSelected, vm in
                AnyView(ShapeObjectView(object: obj, isSelected: isSelected, viewModel: vm))
            },
            exportView: { obj in
                AnyView(ExportShapeObjectView(object: obj))
            }
        )
    }

    // MARK: - Private Helpers

    private func makeShape(
        from start: CGPoint,
        to end: CGPoint,
        viewModel: CanvasViewModel
    ) -> ShapeObject? {
        let origin = CGPoint(x: min(start.x, end.x), y: min(start.y, end.y))
        let size = CGSize(width: abs(end.x - start.x), height: abs(end.y - start.y))
        guard size.width > 1 && size.height > 1 else { return nil }

        // Get stored tool attributes
        let attrs = viewModel.currentToolAttributes

        let strokeColor = attrs["strokeColor"] as? Color ?? .black
        let strokeWidth = attrs["strokeWidth"] as? CGFloat ?? 2.0
        let strokeStyle = attrs["strokeStyle"] as? StrokeStyleType ?? .solid
        let fillColor = attrs["fillColor"] as? Color ?? .white
        let fillOpacity = attrs["fillOpacity"] as? CGFloat ?? 1.0

        // Build text attributes from tool settings
        let textColor = attrs["textColor"] as? Color ?? .black
        let fontSize = attrs["fontSize"] as? CGFloat ?? 16.0
        let fontFamily = attrs["fontFamily"] as? String ?? "System"
        let textAttrs = TextAttributes(
            fontFamily: fontFamily,
            fontSize: fontSize,
            textColor: CodableColor(textColor)
        )

        // Use memberwise initializer to set stroke and fill independently
        return ShapeObject(
            id: UUID(),
            position: origin,
            size: size,
            svgPath: svgPath,
            toolId: toolType.id,
            strokeColor: strokeColor,
            fillColor: fillColor,
            strokeWidth: strokeWidth,
            strokeStyle: strokeStyle,
            fillOpacity: fillOpacity,
            text: "",
            textAttributes: textAttrs,
            isEditing: false,
            autoResizeHeight: false,
            rotation: 0,
            isLocked: false,
            zIndex: 0
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

