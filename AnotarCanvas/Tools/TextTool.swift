//
//  TextTool.swift
//  AnotarCanvas
//

import SwiftUI
import AppKit

public extension DrawingTool {
    public static let text = DrawingTool(id: "text")
}

/// Tool for placing and editing text objects.
/// Click-to-place: clicking empty space creates a new text object,
/// clicking an existing object starts editing it.
public struct TextTool: CanvasTool {
    public let toolType: DrawingTool = .text

    public let name: String = "Text"
    public let category: ToolCategory = .annotation
    public let cursor: NSCursor = .iBeam

    // MARK: - Manifest

    public static let manifest = ToolManifest(
        tool: TextTool(),
        discriminator: "text",
        interactiveView: { obj, isSelected, vm in
            AnyView(TextObjectView(object: obj, viewModel: vm, isSelected: isSelected))
        },
        exportView: { obj in
            AnyView(ExportTextObjectView(object: obj))
        }
    )

    public func handleClick(
        at point: CGPoint,
        viewModel: CanvasViewModel,
        shiftHeld: Bool
    ) {
        let isEditing = viewModel.isAnyObjectEditing

        // Check if clicking on existing object
        if let objectId = viewModel.selectObject(at: point) {
            viewModel.startEditing(objectId: objectId)
        } else if isEditing {
            // Currently editing - just commit without creating new
            viewModel.deselectAll()
        } else {
            // Not editing - construct and add new text object, then start editing.
            // Offset so the blinking text cursor aligns with where the user clicked.
            // Horizontal: 4pt textContainerInset.
            // Vertical: 4pt inset + ~6pt font leading above the blinking caret.
            let newObj = TextObject(
                position: CGPoint(x: point.x - 4, y: point.y - 10),
                text: "",
                fontSize: viewModel.activeTextSize,
                color: viewModel.activeColor,
                isEditing: true
            )
            let newId = viewModel.addObject(newObj)
            viewModel.startEditing(objectId: newId)
        }
    }
}
