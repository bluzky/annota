//
//  PencilTool.swift
//  AnotarCanvas
//

import SwiftUI

public extension DrawingTool {
    public static let pencil = DrawingTool(id: "pencil")
}

/// Tool for freehand pencil drawing.
/// Accumulates sampled points during drag into a live preview, then commits
/// the completed stroke as a PencilObject on drag-end.
///
/// Points are down-sampled: a new point is only appended when the cursor has
/// moved at least `minPointDistance` canvas-units from the previous sample.
/// This reduces the stored point count while preserving visual fidelity.
public struct PencilTool: CanvasTool {
    public let toolType: DrawingTool = .pencil

    public let name: String = "Pencil"
    public let category: ToolCategory = .drawing
    public let cursor: NSCursor = .crosshair

    /// Pencil only supports stroke attributes (no fill, no label text)
    public var capabilities: Set<ToolCapability> {
        [.stroke]
    }

    /// Minimum canvas-distance between consecutive stored points.
    private let minPointDistance: CGFloat = 4

    /// Minimum total travel distance to create a stroke (prevents accidental dots)
    private let minStrokeDistance: CGFloat = 3

    public init() {}

    // MARK: - Manifest

    public static let manifest = ToolManifest(
        tool: PencilTool(),
        discriminator: "pencil",
        interactiveView: { obj, isSelected, vm in
            AnyView(PencilObjectView(object: obj, isSelected: isSelected, viewModel: vm))
        },
        exportView: { obj in
            AnyView(ExportPencilObjectView(object: obj))
        }
    )

    // MARK: - CanvasTool

    public func renderPreview(
        start: CGPoint,
        current: CGPoint,
        viewModel: CanvasViewModel
    ) -> AnyView {
        // The live points list is stored in currentToolAttributes
        guard let pts = viewModel.currentToolAttributes["pencilPoints"] as? [CGPoint],
              pts.count >= 2 else {
            return AnyView(EmptyView())
        }

        let attrs = viewModel.currentToolAttributes
        let strokeColor = attrs["strokeColor"] as? Color ?? .black
        let strokeWidth = attrs["strokeWidth"] as? CGFloat ?? 2.0
        let strokeStyle = attrs["strokeStyle"] as? StrokeStyleType ?? .solid

        let preview = PencilObject(
            points: pts,
            strokeColor: strokeColor,
            strokeWidth: strokeWidth,
            strokeStyle: strokeStyle
        )

        return AnyView(
            preview.smoothPath()
                .stroke(strokeColor, style: strokeStyle.swiftUIStrokeStyle(lineWidth: strokeWidth))
        )
    }

    public func handleDragChanged(
        start: CGPoint,
        current: CGPoint,
        viewModel: CanvasViewModel
    ) {
        var pts = viewModel.currentToolAttributes["pencilPoints"] as? [CGPoint] ?? []

        if pts.isEmpty {
            pts.append(start)
        }

        if let last = pts.last {
            let dx = current.x - last.x
            let dy = current.y - last.y
            if hypot(dx, dy) >= minPointDistance {
                pts.append(current)
            }
        }

        viewModel.currentToolAttributes["pencilPoints"] = pts
        viewModel.dragStartPoint = start
        viewModel.currentDragPoint = current
    }

    public func handleDragEnded(
        start: CGPoint,
        end: CGPoint,
        viewModel: CanvasViewModel,
        shiftHeld: Bool
    ) {
        defer {
            // Always clear transient state
            viewModel.currentToolAttributes["pencilPoints"] = nil
            viewModel.dragStartPoint = nil
            viewModel.currentDragPoint = nil
        }

        guard var pts = viewModel.currentToolAttributes["pencilPoints"] as? [CGPoint],
              !pts.isEmpty else { return }

        // Ensure end point is included
        if let last = pts.last, hypot(end.x - last.x, end.y - last.y) > 0.5 {
            pts.append(end)
        }

        // Require at least 2 points and some minimum travel distance
        guard pts.count >= 2 else { return }
        let totalTravel = zip(pts, pts.dropFirst())
            .map { hypot($1.x - $0.x, $1.y - $0.y) }
            .reduce(0, +)
        guard totalTravel > minStrokeDistance else { return }

        let attrs = viewModel.currentToolAttributes
        let strokeColor = attrs["strokeColor"] as? Color ?? .black
        let strokeWidth = attrs["strokeWidth"] as? CGFloat ?? 2.0
        let strokeStyle = attrs["strokeStyle"] as? StrokeStyleType ?? .solid

        let pencil = PencilObject(
            points: pts,
            strokeColor: strokeColor,
            strokeWidth: strokeWidth,
            strokeStyle: strokeStyle
        )
        viewModel.addObject(pencil)
    }
}
