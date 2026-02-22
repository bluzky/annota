//
//  TextTool.swift
//  texttool
//

import SwiftUI

extension DrawingTool {
    static let text = DrawingTool(id: "text")
}

/// Tool for placing and editing text objects.
/// Click-to-place: clicking empty space creates a new text object,
/// clicking an existing object starts editing it.
struct TextTool: CanvasTool {
    let toolType: DrawingTool = .text

    var metadata: ToolMetadata {
        ToolMetadata(
            name: "Text",
            icon: "textformat",
            category: .annotation,
            cursorType: .iBeam,
            shortcutKey: "T"
        )
    }

    // MARK: - Manifest

    static let manifest = ToolManifest(
        tool: TextTool(),
        discriminator: "text",
        interactiveView: { obj, isSelected, vm in
            AnyView(TextObjectView(object: obj, viewModel: vm, isSelected: isSelected))
        },
        exportView: { obj in
            AnyView(ExportTextObjectView(object: obj))
        }
    )

    func handleClick(
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
            // Not editing - construct and add new text object, then start editing
            let newObj = TextObject(
                position: point,
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
