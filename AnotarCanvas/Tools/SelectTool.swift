//
//  SelectTool.swift
//  AnotarCanvas
//

import SwiftUI
import AppKit

public extension DrawingTool {
    public static let select = DrawingTool(id: "select")
}

/// Registration stub for the select tool.
/// All gesture handling lives in CanvasView — this tool exists solely
/// so ToolRegistry.tool(for: .select) returns non-nil.
public struct SelectTool: CanvasTool {
    public let toolType: DrawingTool = .select

    public let name: String = "Select"
    public let category: ToolCategory = .selection
    public let cursor: NSCursor = .arrow
}
