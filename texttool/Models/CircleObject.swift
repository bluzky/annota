//
//  CircleObject.swift
//  texttool
//
//  Created by Flex on 12/11/25.
//

import SwiftUI

struct CircleObject: Identifiable {
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
        // Calculate distance from center
        let centerX = position.x + size.width / 2
        let centerY = position.y + size.height / 2
        let radiusX = size.width / 2
        let radiusY = size.height / 2

        // Ellipse equation: ((x-cx)/rx)^2 + ((y-cy)/ry)^2 <= 1
        let dx = (point.x - centerX) / radiusX
        let dy = (point.y - centerY) / radiusY
        return (dx * dx + dy * dy) <= 1
    }
}
