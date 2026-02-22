//
//  ShapeTool.swift
//  texttool
//

import SwiftUI

extension DrawingTool {
    /// Returns a DrawingTool whose identity encodes both the "shape" family and the specific preset.
    static func shape(_ preset: ShapePreset) -> DrawingTool {
        DrawingTool(id: "shape-\(preset.name)")
    }
}

/// Tool for creating a specific shape preset via drag-to-create gesture.
/// One instance is registered per preset; the preset is carried as a stored property
/// so no ViewModel inspection is needed during drag handling.
struct ShapeTool: CanvasTool {
    let preset: ShapePreset

    var toolType: DrawingTool { .shape(preset) }

    var metadata: ToolMetadata {
        ToolMetadata(
            name: preset.name,
            icon: preset.sfSymbol,
            category: .shape,
            cursorType: .crosshair,
            shortcutKey: preset == .rectangle ? "R" : nil
        )
    }

    // MARK: - Manifest

    /// Returns a manifest for a specific shape preset.
    /// All presets produce ShapeObject, so the view and codable registrations are
    /// identical for every preset — only the tool instance differs.
    static func manifest(preset: ShapePreset) -> ToolManifest<ShapeObject> {
        ToolManifest(
            tool: ShapeTool(preset: preset),
            discriminator: "shape",
            interactiveView: { obj, isSelected, vm in
                AnyView(ShapeObjectView(object: obj, isSelected: isSelected, viewModel: vm))
            },
            exportView: { obj in
                AnyView(ExportShapeObjectView(object: obj))
            }
        )
    }

    func renderPreview(
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
        let finalEnd = clampedEnd(start: start, current: end, shiftHeld: shiftHeld)
        guard let shape = makeShape(from: start, to: finalEnd, viewModel: viewModel) else { return }
        viewModel.addObject(shape)
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
