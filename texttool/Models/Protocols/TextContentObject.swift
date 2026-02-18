//
//  TextContentObject.swift
//  texttool
//
//  Created by Claude on 2/18/26.
//

import SwiftUI

/// Protocol for canvas objects that contain text content
protocol TextContentObject: CanvasObject {
    /// The text content of this object
    var text: String { get set }

    /// Text styling attributes
    var textAttributes: TextAttributes { get set }

    /// Whether the text is currently being edited
    var isEditing: Bool { get set }
}

// MARK: - Default Implementations

extension TextContentObject {
    /// Returns true if this object has any text content
    var hasText: Bool {
        !text.isEmpty
    }

    /// The font derived from text attributes
    var font: Font {
        textAttributes.font
    }

    /// Calculate the size needed to fit the current text
    /// - Parameter maxWidth: Maximum width constraint (nil for no constraint)
    /// - Returns: The size needed to fit the text
    func textSize(maxWidth: CGFloat? = nil) -> CGSize {
        let nsFont = textAttributes.nsFont
        let attributes: [NSAttributedString.Key: Any] = [
            .font: nsFont
        ]

        if let maxWidth = maxWidth {
            let constraintRect = CGSize(width: maxWidth, height: .greatestFiniteMagnitude)
            let boundingBox = text.boundingRect(
                with: constraintRect,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes,
                context: nil
            )
            return CGSize(
                width: ceil(boundingBox.width),
                height: ceil(boundingBox.height)
            )
        } else {
            let size = (text as NSString).size(withAttributes: attributes)
            return CGSize(
                width: ceil(size.width),
                height: ceil(size.height)
            )
        }
    }

    /// Calculate the frame for text within this object's bounds
    /// - Parameter padding: Padding to apply inside the bounds
    /// - Returns: The frame for text placement
    func textFrame(padding: CGFloat = 8) -> CGRect {
        let bounds = boundingBox()
        return bounds.insetBy(dx: padding, dy: padding)
    }
}
