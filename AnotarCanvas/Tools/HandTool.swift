//
//  HandTool.swift
//  texttool
//

import SwiftUI

public extension DrawingTool {
    public static let hand = DrawingTool(id: "hand")
}

/// Registration stub for the hand (pan) tool.
/// All gesture handling lives in CanvasView — this tool exists solely
/// so ToolRegistry.tool(for: .hand) returns non-nil, eliminating the
/// need for hardcoded DrawingTool case guards at call sites.
public struct HandTool: CanvasTool {
    public let toolType: DrawingTool = .hand

    public var metadata: ToolMetadata {
        ToolMetadata(
            name: "Hand",
            icon: "hand.raised",
            category: .selection,
            cursorType: .openHand,
            shortcutKey: "H"
        )
    }
}
