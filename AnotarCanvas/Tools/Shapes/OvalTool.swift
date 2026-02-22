//
//  OvalTool.swift
//  AnotarCanvas
//
//  Oval shape tool
//

import Foundation

public class OvalTool: ShapeTool {
    public override var name: String {
        "Oval"
    }

    public override var toolType: DrawingTool {
        .oval
    }

    public override var svgPath: String {
        """
        M 50 0
        C 77.6 0 100 22.4 100 50
        C 100 77.6 77.6 100 50 100
        C 22.4 100 0 77.6 0 50
        C 0 22.4 22.4 0 50 0 Z
        """
    }
}
