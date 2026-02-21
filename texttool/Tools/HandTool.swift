//
//  HandTool.swift
//  texttool
//

import SwiftUI

extension DrawingTool {
    static let hand = DrawingTool(id: "hand")
}

/// Registration stub for the hand (pan) tool.
/// All gesture handling lives in CanvasView — this tool exists solely
/// so ToolRegistry.tool(for: .hand) returns non-nil, eliminating the
/// need for hardcoded DrawingTool case guards at call sites.
struct HandTool: CanvasTool {
    let toolType: DrawingTool = .hand

    var metadata: ToolMetadata {
        ToolMetadata(
            name: "Hand",
            icon: "hand.raised",
            category: .selection,
            cursorType: .openHand,
            shortcutKey: "H"
        )
    }
}
