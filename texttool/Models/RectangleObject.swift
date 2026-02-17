//
//  RectangleObject.swift
//  texttool
//
//  Created by Flex on 12/11/25.
//

import SwiftUI

struct RectangleObject: Identifiable {
    let id: UUID
    var position: CGPoint
    var size: CGSize
    var color: Color
    var text: String
    var isEditing: Bool
    var autoResizeHeight: Bool

    init(id: UUID = UUID(), position: CGPoint, size: CGSize, color: Color = .black, text: String = "", isEditing: Bool = false, autoResizeHeight: Bool = false) {
        self.id = id
        self.position = position
        self.size = size
        self.color = color
        self.text = text
        self.isEditing = isEditing
        self.autoResizeHeight = autoResizeHeight
    }

    func contains(_ point: CGPoint) -> Bool {
        let bounds = CGRect(origin: position, size: size)
        return bounds.contains(point)
    }
}
