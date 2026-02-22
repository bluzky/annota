//
//  TextToolPlugin.swift
//  texttool
//

import SwiftUI

/// Tool plugin for placing and editing text objects.
/// Click-to-place tool: clicking empty space creates a new text object,
/// clicking an existing object starts editing it.
struct TextToolPlugin: CanvasTool {
    let id = "text-tool"
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
            // Not editing - create new text object
            let newId = viewModel.addTextObject(at: point)
            viewModel.startEditing(objectId: newId)
        }
    }
}
