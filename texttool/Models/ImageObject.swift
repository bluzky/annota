//
//  ImageObject.swift
//  texttool
//

import SwiftUI
import AppKit

/// Cache for decoded NSImages keyed by image data identity.
/// Avoids re-decoding PNG data on every SwiftUI re-render.
private let imageCache = NSCache<NSData, NSImage>()

struct ImageObject: CanvasObject, Codable {
    // MARK: - CanvasObject Properties
    let id: UUID
    var position: CGPoint
    var size: CGSize
    var rotation: CGFloat = 0
    var isLocked: Bool = false
    var zIndex: Int = 0

    // MARK: - ImageObject Specific
    var imageData: Data
    var aspectRatio: CGFloat
    var maintainAspectRatio: Bool = true

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        position: CGPoint,
        size: CGSize,
        imageData: Data,
        aspectRatio: CGFloat,
        maintainAspectRatio: Bool = true,
        rotation: CGFloat = 0,
        isLocked: Bool = false,
        zIndex: Int = 0
    ) {
        self.id = id
        self.position = position
        self.size = size
        self.imageData = imageData
        self.aspectRatio = aspectRatio
        self.maintainAspectRatio = maintainAspectRatio
        self.rotation = rotation
        self.isLocked = isLocked
        self.zIndex = zIndex
    }

    // MARK: - Computed Properties

    /// Convert stored PNG data to NSImage for rendering, using a cache
    /// to avoid re-decoding on every SwiftUI body evaluation.
    var nsImage: NSImage? {
        let key = imageData as NSData
        if let cached = imageCache.object(forKey: key) {
            return cached
        }
        guard let image = NSImage(data: imageData) else { return nil }
        imageCache.setObject(image, forKey: key)
        return image
    }

    // MARK: - Static Helpers

    /// Fit image dimensions within maxDimension while preserving aspect ratio
    static func fittingSize(for imageSize: CGSize, maxDimension: CGFloat = 300) -> CGSize {
        let aspectRatio = imageSize.width / imageSize.height

        if imageSize.width > imageSize.height {
            // Landscape: constrain width
            let width = min(imageSize.width, maxDimension)
            return CGSize(width: width, height: width / aspectRatio)
        } else {
            // Portrait or square: constrain height
            let height = min(imageSize.height, maxDimension)
            return CGSize(width: height * aspectRatio, height: height)
        }
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case id, position, size, rotation, isLocked, zIndex
        case imageData, aspectRatio, maintainAspectRatio
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        position = try container.decode(CGPoint.self, forKey: .position)
        size = try container.decode(CGSize.self, forKey: .size)
        rotation = try container.decodeIfPresent(CGFloat.self, forKey: .rotation) ?? 0
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        zIndex = try container.decodeIfPresent(Int.self, forKey: .zIndex) ?? 0
        imageData = try container.decode(Data.self, forKey: .imageData)
        aspectRatio = try container.decode(CGFloat.self, forKey: .aspectRatio)
        maintainAspectRatio = try container.decodeIfPresent(Bool.self, forKey: .maintainAspectRatio) ?? true
    }

    // MARK: - Copy

    func copied(newId: UUID, zIndex: Int, offset: CGPoint) -> ImageObject {
        ImageObject(
            id: newId,
            position: CGPoint(x: position.x + offset.x, y: position.y + offset.y),
            size: size,
            imageData: imageData,
            aspectRatio: aspectRatio,
            maintainAspectRatio: maintainAspectRatio,
            rotation: rotation,
            isLocked: false,
            zIndex: zIndex
        )
    }

    // MARK: - CanvasObject Methods

    func contains(_ point: CGPoint) -> Bool {
        // Transform point to local coordinates if rotated
        let localPoint = rotation != 0 ? transformToLocal(point) : point

        // Simple rectangular hit test
        let bounds = CGRect(origin: position, size: size)
        return bounds.contains(localPoint)
    }

    func boundingBox() -> CGRect {
        CGRect(origin: position, size: size)
    }
}
