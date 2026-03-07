//
//  AnnotaDocument.swift
//  AnotarCanvas
//

import Foundation

/// File format for persisting canvas state to `.annota` files.
/// Reuses CodableCanvasObject serialization (same as clipboard).
public struct AnnotaDocument: Codable {
    public let version: Int
    public let viewport: ViewportData
    public let objects: [CodableCanvasObject]

    public struct ViewportData: Codable {
        public let offsetX: CGFloat
        public let offsetY: CGFloat
        public let scale: CGFloat

        public init(viewport: ViewportState) {
            self.offsetX = viewport.offset.x
            self.offsetY = viewport.offset.y
            self.scale = viewport.scale
        }

        public func toViewportState() -> ViewportState {
            ViewportState(offset: CGPoint(x: offsetX, y: offsetY), scale: scale)
        }
    }

    /// Encode current canvas state into JSON data.
    @MainActor
    public static func encode(objects: [AnyCanvasObject], viewport: ViewportState) -> Data? {
        let codableObjects = objects.compactMap { CodableCanvasObject.from($0) }
        let document = AnnotaDocument(
            version: 1,
            viewport: ViewportData(viewport: viewport),
            objects: codableObjects
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(document)
    }

    /// Decode an AnnotaDocument from JSON data.
    public static func decode(from data: Data) throws -> AnnotaDocument {
        try JSONDecoder().decode(AnnotaDocument.self, from: data)
    }
}
