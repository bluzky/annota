//
//  HandTool.swift
//  AnotarCanvas
//

import SwiftUI
import AppKit

public extension DrawingTool {
    public static let hand = DrawingTool(id: "hand")
}

/// Registration stub for the hand (pan) tool.
/// All gesture handling lives in CanvasView — this tool exists solely
/// so ToolRegistry.tool(for: .hand) returns non-nil.
public struct HandTool: CanvasTool {
    public let toolType: DrawingTool = .hand

    public let name: String = "Hand"
    public let category: ToolCategory = .selection
    public let cursor: NSCursor = .openHand

    /// Hand tool has no creation capabilities (empty set)
    public var capabilities: Set<ToolCapability> {
        []
    }

    public init() {}
}
