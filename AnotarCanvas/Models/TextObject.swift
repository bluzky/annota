//
//  TextObject.swift
//  AnotarCanvas
//
//  Created by Flex on 12/11/25.
//

import SwiftUI
import AppKit

public struct TextObject: CanvasObject, TextContentObject, CopyableCanvasObject {
    // MARK: - CanvasObject Properties
    public let id: UUID
    public var position: CGPoint
    public var size: CGSize
    public var rotation: CGFloat = 0
    public var isLocked: Bool = false
    public var zIndex: Int = 0

    // MARK: - TextContentObject Properties
    public var text: String
    public var textAttributes: TextAttributes
    public var isEditing: Bool

    // MARK: - TextObject Specific
    public var width: CGFloat? = nil   // nil = free-grow, non-nil = constrained to this width

    // MARK: - Backward Compatibility

    /// Convenience accessor for font size (backward compatibility)
    public var fontSize: CGFloat {
        get { textAttributes.fontSize }
        set { textAttributes.fontSize = newValue }
    }

    /// Convenience accessor for color (backward compatibility)
    public var color: Color {
        get { textAttributes.color }
        set { textAttributes.color = newValue }
    }

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        position: CGPoint,
        text: String = "",
        fontSize: CGFloat = 16,
        fontFamily: String = "System",
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
            fontFamily: fontFamily,
            fontSize: fontSize,
            textColor: CodableColor(color)
        )
        self.isEditing = isEditing
        self.rotation = rotation
        self.isLocked = isLocked
        self.zIndex = zIndex

        // Calculate initial size using NSAttributedString for accurate measurement
        let font = textAttributes.nsFont
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let measured = (text as NSString).boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: attrs
        )
        let measuredWidth = max(measured.width, fontSize * 2)
        let measuredHeight = max(measured.height, fontSize * 1.2)
        self.size = CGSize(width: measuredWidth + 8, height: measuredHeight + 8)
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case id, position, size, rotation, isLocked, zIndex
        case text, textAttributes, width
    }

    // Separate enum used only while decoding legacy data
    private enum LegacyCodingKeys: String, CodingKey {
        case maxWidth
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        position = try container.decode(CGPoint.self, forKey: .position)
        size = try container.decode(CGSize.self, forKey: .size)
        rotation = try container.decodeIfPresent(CGFloat.self, forKey: .rotation) ?? 0
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        zIndex = try container.decodeIfPresent(Int.self, forKey: .zIndex) ?? 0
        text = try container.decode(String.self, forKey: .text)
        textAttributes = try container.decode(TextAttributes.self, forKey: .textAttributes)
        // Prefer new `width` key; fall back to legacy `maxWidth` (treat the old 200 default as nil/free-grow)
        if let w = try container.decodeIfPresent(CGFloat.self, forKey: .width) {
            width = w
        } else {
            let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
            if let legacy = try legacyContainer.decodeIfPresent(CGFloat.self, forKey: .maxWidth), legacy != 200 {
                width = legacy
            } else {
                width = nil
            }
        }
        isEditing = false
    }

    // MARK: - Copy

    public func copied(newId: UUID, zIndex: Int, offset: CGPoint) -> TextObject {
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
        copy.width = width
        return copy
    }

    // MARK: - CanvasObject Methods

    public func contains(_ point: CGPoint) -> Bool {
        // Transform point to local coordinates if rotated
        let localPoint = rotation != 0 ? transformToLocal(point) : point

        // Use stored size directly
        let bounds = CGRect(origin: position, size: size)
        // Add 5pt padding for better hit testing
        return bounds.insetBy(dx: -5, dy: -5).contains(localPoint)
    }

    public func boundingBox() -> CGRect {
        CGRect(origin: position, size: size)
    }
}
