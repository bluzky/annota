//
//  TextObject.swift
//  texttool
//
//  Created by Flex on 12/11/25.
//

import SwiftUI

struct TextObject: Identifiable {
    let id: UUID
    var position: CGPoint
    var text: String
    var fontSize: CGFloat
    var color: Color
    var isEditing: Bool

    init(id: UUID = UUID(), position: CGPoint, text: String = "", fontSize: CGFloat = 16, color: Color = .black, isEditing: Bool = false) {
        self.id = id
        self.position = position
        self.text = text
        self.fontSize = fontSize
        self.color = color
        self.isEditing = isEditing
    }

    func contains(_ point: CGPoint) -> Bool {
        // Calculate approximate text bounds
        // Position is now top-left corner, not center
        let approximateWidth = max(CGFloat(text.count) * fontSize * 0.6, fontSize * 2)
        let height = fontSize * 1.2
        let bounds = CGRect(
            x: position.x,
            y: position.y,
            width: approximateWidth + 8, // Add padding
            height: height + 8
        )
        // Add 10pt padding for better hit testing
        return bounds.insetBy(dx: -10, dy: -10).contains(point)
    }
}
