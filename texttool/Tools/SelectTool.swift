//
//  SelectTool.swift
//  texttool
//

import SwiftUI

extension DrawingTool {
    static let select = DrawingTool(id: "select")
}

/// Registration stub for the select tool.
/// All gesture handling lives in CanvasView — this tool exists solely
/// so ToolRegistry.tool(for: .select) returns non-nil, eliminating the
/// need for hardcoded DrawingTool case guards at call sites.
struct SelectTool: CanvasTool {
    let toolType: DrawingTool = .select

    var metadata: ToolMetadata {
        ToolMetadata(
            name: "Select",
            icon: "arrow.up.left",
            category: .selection,
            cursorType: .arrow,
            shortcutKey: "V"
        )
    }
}
