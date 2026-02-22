//
//  DrawingTool+Shapes.swift
//  AnotarCanvas
//
//  Extension for built-in shape tool identities
//

import Foundation

public extension DrawingTool {
    // Built-in shape tools
    static let rectangle = DrawingTool(id: "rectangle")
    static let oval = DrawingTool(id: "oval")
    static let triangle = DrawingTool(id: "triangle")
    static let diamond = DrawingTool(id: "diamond")
    static let star = DrawingTool(id: "star")

    // Factory method for custom shapes (plugins)
    static func shape(id: String) -> DrawingTool {
        DrawingTool(id: id)
    }
}
