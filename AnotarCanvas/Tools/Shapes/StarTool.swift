//
//  StarTool.swift
//  AnotarCanvas
//
//  Star shape tool
//

import Foundation

public class StarTool: ShapeTool {
    public override var name: String {
        "Star"
    }

    public override var toolType: DrawingTool {
        .star
    }

    public override var svgPath: String {
        """
        M 50 0 L 61 35 L 98 35 L 68 57 L 79 91
        L 50 70 L 21 91 L 32 57 L 2 35 L 39 35 Z
        """
    }
}
