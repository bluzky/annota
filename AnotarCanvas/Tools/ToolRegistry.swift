//
//  ToolRegistry.swift
//  AnotarCanvas
//

import SwiftUI
import Combine

/// Singleton registry managing all available canvas tools.
/// Tools are keyed by `toolType.id` for O(1) lookup — no linear scan needed.
@MainActor
public class ToolRegistry: ObservableObject {
    public static let shared = ToolRegistry()

    @Published public private(set) var registeredTools: [String: any CanvasTool] = [:]

    private init() {
        registerBuiltInTools()
    }

    /// Register a tool, keyed by its toolType.id.
    public func register(_ tool: any CanvasTool) {
        registeredTools[tool.toolType.id] = tool
    }

    /// Register a tool together with all registrations for the object type it produces.
    /// This is the preferred registration path: one call covers the tool, its interactive
    /// view, its export view, and its clipboard (Codable) support.
    public func register<Obj: CopyableCanvasObject>(_ manifest: ToolManifest<Obj>) {
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
    public func register<Obj: CopyableCanvasObject>(_ manifest: ObjectManifest<Obj>) {
        ObjectViewRegistry.register(Obj.self) { obj, isSelected, vm in
            manifest.interactiveView(obj, isSelected, vm)
        }
        ObjectViewRegistry.registerExport(Obj.self) { obj in
            manifest.exportView(obj)
        }
        CodableObjectRegistry.register(Obj.self, discriminator: manifest.discriminator)
    }

    /// Unregister a tool by its DrawingTool identity.
    public func unregister(_ toolType: DrawingTool) {
        registeredTools.removeValue(forKey: toolType.id)
    }

    /// Get the tool instance for a given DrawingTool — O(1) dictionary lookup.
    public func tool(for type: DrawingTool) -> (any CanvasTool)? {
        registeredTools[type.id]
    }

    /// Get all tools in a specific category.
    public func tools(in category: ToolCategory) -> [any CanvasTool] {
        registeredTools.values.filter { $0.category == category }
    }

    /// All registered DrawingTool identifiers.
    public var toolIds: [String] {
        Array(registeredTools.keys)
    }

    private func registerBuiltInTools() {
        // Tool-only (no produced object) — registered directly
        register(SelectTool())
        register(HandTool())
        register(ArrowTool())

        // Shape tools — each shape shares ShapeObject registrations
        // Only the first shape registration reaches the ObjectViewRegistry/CodableObjectRegistry
        // calls; subsequent ones are no-ops for those registries (same discriminator).
        register(RectangleTool().manifest())
        register(OvalTool().manifest())
        register(TriangleTool().manifest())
        register(DiamondTool().manifest())
        register(StarTool().manifest())

        // Line and text tools carry their own object registrations
        register(LineTool.manifest)
        register(TextTool.manifest)

        // ImageObject has no toolbar tool — register views and codable support directly.
        register(ImageObject.objectManifest)
    }
}
