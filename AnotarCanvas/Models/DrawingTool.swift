//
//  DrawingTool.swift
//  texttool
//
//  Created by Flex on 12/11/25.
//

import Foundation

/// A lightweight value type identifying which tool is active.
/// Tool identities are declared as static constants in each tool file —
/// this file is never modified when adding a new tool.
public struct DrawingTool: Hashable {
    public let id: String

    public init(id: String) {
        self.id = id
    }
}
