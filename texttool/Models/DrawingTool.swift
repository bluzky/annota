//
//  DrawingTool.swift
//  texttool
//
//  Created by Flex on 12/11/25.
//

import Foundation

enum DrawingTool: Equatable {
    case select
    case text
    case shape(ShapePreset)   // replaces .rectangle and .oval
    case hand
}

extension DrawingTool {
    var isShapeTool: Bool {
        if case .shape = self { return true }
        return false
    }

    var shapePreset: ShapePreset? {
        if case .shape(let p) = self { return p }
        return nil
    }
}
