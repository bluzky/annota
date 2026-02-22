//
//  ImageObject.swift
//  texttool
//

import SwiftUI
import AppKit

/// Cache for decoded NSImages keyed by object UUID.
/// imageData is immutable (let) on ImageObject — a new object with a new id is always
/// created when the image changes — so the UUID key never goes stale.
private let imageCache = NSCache<NSString, NSImage>()

public struct ImageObject: CanvasObject, CopyableCanvasObject {
    // MARK: - CanvasObject Properties
    public let id: UUID
    public var position: CGPoint
    public var size: CGSize
    public var rotation: CGFloat = 0
    public var isLocked: Bool = false
    public var zIndex: Int = 0

    // MARK: - ImageObject Specific
    public let imageData: Data
    public var aspectRatio: CGFloat
    public var maintainAspectRatio: Bool = true

    // MARK: - Initialization

    public init(
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

    /// Convert stored PNG data to NSImage for rendering, using a cache keyed by UUID
    /// to avoid re-decoding on every SwiftUI body evaluation.
    /// Safe to use UUID as key because imageData is immutable (let) — the UUID never
    /// outlives the data it was created with.
    public var nsImage: NSImage? {
        let key = id.uuidString as NSString
        if let cached = imageCache.object(forKey: key) {
            return cached
        }
        guard let image = NSImage(data: imageData) else { return nil }
        imageCache.setObject(image, forKey: key)
        return image
    }

    // MARK: - Static Helpers

    /// Fit image dimensions within maxDimension while preserving aspect ratio
    public static func fittingSize(for imageSize: CGSize, maxDimension: CGFloat = 300) -> CGSize {
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

    public init(from decoder: Decoder) throws {
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

    public func copied(newId: UUID, zIndex: Int, offset: CGPoint) -> ImageObject {
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

    public func contains(_ point: CGPoint) -> Bool {
        // Transform point to local coordinates if rotated
        let localPoint = rotation != 0 ? transformToLocal(point) : point

        // Simple rectangular hit test
        let bounds = CGRect(origin: position, size: size)
        return bounds.contains(localPoint)
    }

    public func boundingBox() -> CGRect {
        CGRect(origin: position, size: size)
    }

    // MARK: - ObjectManifest

    /// ImageObject has no dedicated toolbar tool — it is inserted via paste or drag-drop.
    /// This manifest registers its views and codable support without a tool entry.
    public static let objectManifest = ObjectManifest<ImageObject>(
        discriminator: "image",
        interactiveView: { obj, isSelected, vm in
            AnyView(ImageObjectView(object: obj, isSelected: isSelected, viewModel: vm))
        },
        exportView: { obj in
            AnyView(ExportImageObjectView(object: obj))
        }
    )
}
