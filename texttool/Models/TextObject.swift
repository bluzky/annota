//
//  TextObject.swift
//  texttool
//
//  Created by Flex on 12/11/25.
//

import SwiftUI

struct TextObject: CanvasObject, TextContentObject {
    // MARK: - CanvasObject Properties
    let id: UUID
    var position: CGPoint
    var size: CGSize
    var rotation: CGFloat = 0
    var isLocked: Bool = false
    var zIndex: Int = 0

    // MARK: - TextContentObject Properties
    var text: String
    var textAttributes: TextAttributes
    var isEditing: Bool

    // MARK: - TextObject Specific
    var maxWidth: CGFloat = 200

    // MARK: - Backward Compatibility

    /// Convenience accessor for font size (backward compatibility)
    var fontSize: CGFloat {
        get { textAttributes.fontSize }
        set { textAttributes.fontSize = newValue }
    }

    /// Convenience accessor for color (backward compatibility)
    var color: Color {
        get { textAttributes.color }
        set { textAttributes.color = newValue }
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        position: CGPoint,
        text: String = "",
        fontSize: CGFloat = 16,
        color: Color = .black,
        isEditing: Bool = false,
        rotation: CGFloat = 0,
        isLocked: Bool = false,
        zIndex: Int = 0
    ) {
        self.id = id
        self.position = position
        self.text = text
        self.textAttributes = TextAttributes(
            fontSize: fontSize,
            textColor: CodableColor(color)
        )
        self.isEditing = isEditing
        self.rotation = rotation
        self.isLocked = isLocked
        self.zIndex = zIndex

        // Calculate initial size based on text
        let approximateWidth = max(CGFloat(text.count) * fontSize * 0.6, fontSize * 2)
        let height = fontSize * 1.2
        self.size = CGSize(width: approximateWidth + 8, height: height + 8)
    }

    // MARK: - CanvasObject Methods

    func contains(_ point: CGPoint) -> Bool {
        // Transform point to local coordinates if rotated
        let localPoint = rotation != 0 ? transformToLocal(point) : point

        // Use stored size directly
        let bounds = CGRect(origin: position, size: size)
        // Add 5pt padding for better hit testing
        return bounds.insetBy(dx: -5, dy: -5).contains(localPoint)
    }

    func boundingBox() -> CGRect {
        CGRect(origin: position, size: size)
    }
}
