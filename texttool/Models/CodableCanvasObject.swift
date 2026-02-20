//
//  CodableCanvasObject.swift
//  texttool
//

import Foundation

/// Codable wrapper for clipboard serialization of canvas objects
enum CodableCanvasObject: Codable {
    case text(TextObject)
    case shape(ShapeObject)

    /// Extract from an AnyCanvasObject
    static func from(_ anyObject: AnyCanvasObject) -> CodableCanvasObject? {
        if let textObj = anyObject.asTextObject {
            return .text(textObj)
        } else if let shapeObj = anyObject.asShapeObject {
            return .shape(shapeObj)
        }
        return nil
    }

    /// Create a new AnyCanvasObject with a fresh ID, zIndex, and position offset
    func toAnyCanvasObject(newId: UUID, zIndex: Int, offset: CGPoint) -> AnyCanvasObject {
        switch self {
        case .text(let textObj):
            return AnyCanvasObject(textObj.copied(newId: newId, zIndex: zIndex, offset: offset))
        case .shape(let shapeObj):
            return AnyCanvasObject(shapeObj.copied(newId: newId, zIndex: zIndex, offset: offset))
        }
    }
}
