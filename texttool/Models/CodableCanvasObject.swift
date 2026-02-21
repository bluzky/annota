//
//  CodableCanvasObject.swift
//  texttool
//

import Foundation

/// Protocol for canvas objects that support clipboard copy/paste via Codable serialization.
protocol CopyableCanvasObject: CanvasObject, Codable {
    func copied(newId: UUID, zIndex: Int, offset: CGPoint) -> Self
}

// MARK: - CodableObjectRegistry

/// Central registry mapping type discriminator strings to encode/decode/copy closures.
/// Adding a new copyable object type only requires a registration call.
/// @MainActor ensures all dictionary mutations happen on the main thread.
@MainActor
enum CodableObjectRegistry {
    /// Forward map: discriminator string → decode + copy closures
    private static var decoders: [String: (Data) throws -> any CopyableCanvasObject] = [:]
    /// Forward map: discriminator string → encode closure (from AnyCanvasObject)
    private static var encoders: [String: (AnyCanvasObject) -> Data?] = [:]
    /// Reverse map: ObjectIdentifier → discriminator string
    private static var discriminators: [ObjectIdentifier: String] = [:]

    /// Register a CopyableCanvasObject type with the given discriminator string.
    static func register<T: CopyableCanvasObject>(_ type: T.Type, discriminator: String) {
        discriminators[ObjectIdentifier(type)] = discriminator

        decoders[discriminator] = { data in
            try JSONDecoder().decode(T.self, from: data)
        }

        encoders[discriminator] = { anyObj in
            guard let typed = anyObj.asType(T.self) else { return nil }
            return try? JSONEncoder().encode(typed)
        }
    }

    /// Look up the discriminator string for a concrete type stored in AnyCanvasObject.
    static func discriminator(for object: AnyCanvasObject) -> String? {
        discriminators[object.underlyingTypeId]
    }

    /// Encode an AnyCanvasObject to Data using its registered encoder.
    static func encode(_ object: AnyCanvasObject) -> Data? {
        guard let disc = discriminator(for: object),
              let encoder = encoders[disc] else { return nil }
        return encoder(object)
    }

    /// Decode a CopyableCanvasObject from Data using the discriminator.
    static func decode(discriminator: String, data: Data) -> (any CopyableCanvasObject)? {
        guard let decoder = decoders[discriminator] else { return nil }
        return try? decoder(data)
    }
}

// MARK: - CodableCanvasObject

/// Codable wrapper for clipboard serialization of canvas objects.
/// Uses CodableObjectRegistry for type-agnostic encode/decode.
struct CodableCanvasObject: Codable {
    let typeDiscriminator: String
    let objectData: Data

    /// Extract from an AnyCanvasObject using the registry.
    static func from(_ anyObject: AnyCanvasObject) -> CodableCanvasObject? {
        guard let disc = CodableObjectRegistry.discriminator(for: anyObject),
              let data = CodableObjectRegistry.encode(anyObject) else {
            return nil
        }
        return CodableCanvasObject(typeDiscriminator: disc, objectData: data)
    }

    /// Create a new AnyCanvasObject with a fresh ID, zIndex, and position offset.
    /// Returns nil if the discriminator is not registered.
    func toAnyCanvasObject(newId: UUID, zIndex: Int, offset: CGPoint) -> AnyCanvasObject? {
        guard let decoded = CodableObjectRegistry.decode(discriminator: typeDiscriminator, data: objectData) else {
            return nil
        }
        let copied = decoded.copied(newId: newId, zIndex: zIndex, offset: offset)
        return AnyCanvasObject(copied)
    }
}
