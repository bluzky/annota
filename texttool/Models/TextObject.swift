//
//  TextObject.swift
//  texttool
//
//  Created by Flex on 12/11/25.
//

import SwiftUI

struct TextObject: CanvasObject, TextContentObject, Codable {
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

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case id, position, size, rotation, isLocked, zIndex
        case text, textAttributes, maxWidth
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        position = try container.decode(CGPoint.self, forKey: .position)
        size = try container.decode(CGSize.self, forKey: .size)
        rotation = try container.decodeIfPresent(CGFloat.self, forKey: .rotation) ?? 0
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        zIndex = try container.decodeIfPresent(Int.self, forKey: .zIndex) ?? 0
        text = try container.decode(String.self, forKey: .text)
        textAttributes = try container.decode(TextAttributes.self, forKey: .textAttributes)
        maxWidth = try container.decodeIfPresent(CGFloat.self, forKey: .maxWidth) ?? 200
        isEditing = false
    }

    // MARK: - Copy

    func copied(newId: UUID, zIndex: Int, offset: CGPoint) -> TextObject {
        var copy = TextObject(
            id: newId,
            position: CGPoint(x: position.x + offset.x, y: position.y + offset.y),
            text: text,
            fontSize: textAttributes.fontSize,
            color: textAttributes.color,
            isEditing: false,
            rotation: rotation,
            isLocked: false,
            zIndex: zIndex
        )
        copy.textAttributes = textAttributes
        copy.size = size
        copy.maxWidth = maxWidth
        return copy
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
