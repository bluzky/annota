//
//  RectangleTool.swift
//  AnotarCanvas
//
//  Rectangle shape tool
//

import Foundation

public class RectangleTool: ShapeTool {
    public override var name: String {
        "Rectangle"
    }

    public override var toolType: DrawingTool {
        .rectangle
    }

    public override var svgPath: String {
        "M 0,0 L 100,0 L 100,100 L 0,100 Z"
    }
}
