//
//  ArrowTool.swift
//  AnotarCanvas
//

import SwiftUI
import AppKit

public extension DrawingTool {
    public static let arrow = DrawingTool(id: "arrow")
}

/// Tool for creating arrows via drag-to-create gesture.
/// Renders preview with arrowhead; creates LineObject with customizable arrowhead styles.
public struct ArrowTool: CanvasTool {
    public let toolType: DrawingTool = .arrow

    public let name: String = "Arrow"
    public let category: ToolCategory = .drawing
    public let cursor: NSCursor = .crosshair

    // MARK: - Custom Attribute Keys
    // Tool-specific attribute keys (pure strings for extensibility)
    public enum CustomAttr {
        public static let startArrowHead = "startArrowHead"
        public static let endArrowHead = "endArrowHead"
    }

    // MARK: - Note
    // ArrowTool produces LineObject — the same type as LineTool.
    // It is registered directly via ToolRegistry.register(_: any CanvasTool);
    // LineTool.manifest covers the shared LineObject view and codable registrations.

    public func renderPreview(
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

        // Get stored tool attributes
        let attrs = viewModel.currentToolAttributes

        // Standard attributes
        let strokeColor = attrs[ObjectAttributes.strokeColor] as? Color ?? .black
        let strokeWidth = attrs[ObjectAttributes.strokeWidth] as? CGFloat ?? 2.0
        let strokeStyle = attrs[ObjectAttributes.strokeStyle] as? StrokeStyleType ?? .solid

        // Custom attributes from customAttributes namespace
        let customAttrs = attrs[ObjectAttributes.customAttributes] as? [String: Any] ?? [:]

        let startArrow: ArrowHead
        if let rawValue = customAttrs[CustomAttr.startArrowHead] as? String {
            startArrow = ArrowHead(rawValue: rawValue) ?? .none
        } else {
            startArrow = .none
        }

        let endArrow: ArrowHead
        if let rawValue = customAttrs[CustomAttr.endArrowHead] as? String {
            endArrow = ArrowHead(rawValue: rawValue) ?? .open
        } else {
            endArrow = .open
        }

        return LineObject(
            startPoint: start,
            endPoint: end,
            strokeColor: strokeColor,
            strokeWidth: strokeWidth,
            strokeStyle: strokeStyle,
            startArrowHead: startArrow,
            endArrowHead: endArrow
        )
    }

    // MARK: - Custom Tool Controls

    public func customToolControls(viewModel: CanvasViewModel) -> AnyView? {
        AnyView(ArrowToolControls(viewModel: viewModel))
    }
}

// MARK: - Arrow Tool UI Controls

struct ArrowToolControls: View {
    @ObservedObject var viewModel: CanvasViewModel

    var body: some View {
        Group {
            Label("Arrow Style", systemImage: "arrow.right")
                .font(.caption)
                .foregroundColor(.secondary)

            Picker("Start", selection: Binding(
                get: {
                    ArrowHead(rawValue: viewModel.getCustomToolAttribute(key: ArrowTool.CustomAttr.startArrowHead) ?? "none") ?? .none
                },
                set: {
                    viewModel.updateCustomToolAttribute(key: ArrowTool.CustomAttr.startArrowHead, value: $0.rawValue)
                }
            )) {
                ForEach(ArrowHead.allCases, id: \.self) { style in
                    Text(style.rawValue.capitalized).tag(style)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 80)
            .help("Start arrowhead")

            Picker("End", selection: Binding(
                get: {
                    ArrowHead(rawValue: viewModel.getCustomToolAttribute(key: ArrowTool.CustomAttr.endArrowHead) ?? "open") ?? .open
                },
                set: {
                    viewModel.updateCustomToolAttribute(key: ArrowTool.CustomAttr.endArrowHead, value: $0.rawValue)
                }
            )) {
                ForEach(ArrowHead.allCases, id: \.self) { style in
                    Text(style.rawValue.capitalized).tag(style)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 80)
            .help("End arrowhead")
        }
    }
}
