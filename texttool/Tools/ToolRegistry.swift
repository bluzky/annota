//
//  ToolRegistry.swift
//  texttool
//

import SwiftUI
import Combine

/// Singleton registry managing all available canvas tools.
/// Tools are keyed by `toolType.id` for O(1) lookup — no linear scan needed.
@MainActor
class ToolRegistry: ObservableObject {
    static let shared = ToolRegistry()

    @Published private(set) var registeredTools: [String: any CanvasTool] = [:]

    private init() {
        registerBuiltInTools()
    }

    /// Register a tool, keyed by its toolType.id.
    func register(_ tool: any CanvasTool) {
        registeredTools[tool.toolType.id] = tool
    }

    /// Register a tool together with all registrations for the object type it produces.
    /// This is the preferred registration path: one call covers the tool, its interactive
    /// view, its export view, and its clipboard (Codable) support.
    func register<Obj: CopyableCanvasObject>(_ manifest: ToolManifest<Obj>) {
        register(manifest.tool)
        ObjectViewRegistry.register(Obj.self) { obj, isSelected, vm in
            manifest.interactiveView(obj, isSelected, vm)
        }
        ObjectViewRegistry.registerExport(Obj.self) { obj in
            manifest.exportView(obj)
        }
        CodableObjectRegistry.register(Obj.self, discriminator: manifest.discriminator)
    }

    /// Register view and codable support for an object type that has no dedicated tool
    /// (e.g. ImageObject, inserted via paste rather than a toolbar tool).
    func register<Obj: CopyableCanvasObject>(_ manifest: ObjectManifest<Obj>) {
        ObjectViewRegistry.register(Obj.self) { obj, isSelected, vm in
            manifest.interactiveView(obj, isSelected, vm)
        }
        ObjectViewRegistry.registerExport(Obj.self) { obj in
            manifest.exportView(obj)
        }
        CodableObjectRegistry.register(Obj.self, discriminator: manifest.discriminator)
    }

    /// Unregister a tool by its DrawingTool identity.
    func unregister(_ toolType: DrawingTool) {
        registeredTools.removeValue(forKey: toolType.id)
    }

    /// Get the tool instance for a given DrawingTool — O(1) dictionary lookup.
    func tool(for type: DrawingTool) -> (any CanvasTool)? {
        registeredTools[type.id]
    }

    /// Get all tools in a specific category.
    func tools(in category: ToolCategory) -> [any CanvasTool] {
        registeredTools.values.filter { $0.metadata.category == category }
    }

    /// All registered DrawingTool identifiers.
    var toolIds: [String] {
        Array(registeredTools.keys)
    }

    private func registerBuiltInTools() {
        // Tool-only (no produced object) — registered directly
        register(SelectTool())
        register(HandTool())
        register(ArrowTool())

        // Shape tools — one per preset, all sharing ShapeObject registrations.
        // Only the first preset registration reaches the ObjectViewRegistry/CodableObjectRegistry
        // calls; subsequent ones are no-ops for those registries (same ObjectIdentifier key).
        for preset in ShapePreset.builtIn {
            register(ShapeTool.manifest(preset: preset))
        }

        // Line and text tools carry their own object registrations
        register(LineTool.manifest)
        register(TextTool.manifest)

        // ImageObject has no toolbar tool — register views and codable support directly.
        register(ImageObject.objectManifest)
    }
}
