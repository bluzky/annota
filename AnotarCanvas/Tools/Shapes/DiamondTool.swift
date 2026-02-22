//
//  DiamondTool.swift
//  AnotarCanvas
//
//  Diamond shape tool
//

import Foundation

public class DiamondTool: ShapeTool {
    public override var name: String {
        "Diamond"
    }

    public override var toolType: DrawingTool {
        .diamond
    }

    public override var svgPath: String {
        "M 50,0 L 100,50 L 50,100 L 0,50 Z"
    }
}
