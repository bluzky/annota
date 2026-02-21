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
    case line
    case arrow
    case hand
}

