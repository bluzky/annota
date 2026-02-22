//
//  TriangleTool.swift
//  AnotarCanvas
//
//  Triangle shape tool
//

import Foundation

public class TriangleTool: ShapeTool {
    public override var name: String {
        "Triangle"
    }

    public override var toolType: DrawingTool {
        .triangle
    }

    public override var svgPath: String {
        "M 50,0 L 100,100 L 0,100 Z"
    }
}
