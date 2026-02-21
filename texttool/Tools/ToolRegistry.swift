//
//  ToolRegistry.swift
//  texttool
//

import SwiftUI
import Combine

/// Singleton registry managing all available canvas tools.
/// Tools register themselves and CanvasView dispatches to them via this registry.
@MainActor
class ToolRegistry: ObservableObject {
    static let shared = ToolRegistry()

    @Published private(set) var registeredTools: [String: any CanvasTool] = [:]

    private init() {
        registerBuiltInTools()
    }

    /// Register a new tool
    func register(_ tool: any CanvasTool) {
        registeredTools[tool.id] = tool
    }

    /// Unregister a tool by ID
    func unregister(id: String) {
        registeredTools.removeValue(forKey: id)
    }

    /// Get tool instance for a given DrawingTool type.
    /// Uses the tool's matches() method to support tools that handle multiple variants
    /// (e.g. ShapeTool matches all .shape(_) types).
    func tool(for type: DrawingTool) -> (any CanvasTool)? {
        registeredTools.values.first { $0.matches(type) }
    }

    /// Get all tools in a specific category
    func tools(in category: ToolCategory) -> [any CanvasTool] {
        registeredTools.values.filter { $0.metadata.category == category }
    }

    /// Get all registered tool IDs
    var toolIds: [String] {
        Array(registeredTools.keys)
    }

    private func registerBuiltInTools() {
        register(ShapeToolPlugin())
        register(LineToolPlugin())
        register(ArrowToolPlugin())
        register(TextToolPlugin())
        registerBuiltInObjectTypes()
    }

    private func registerBuiltInObjectTypes() {
        // Interactive view factories
        ObjectViewRegistry.register(TextObject.self) { obj, isSelected, vm in
            AnyView(TextObjectView(object: obj, viewModel: vm, isSelected: isSelected))
        }
        ObjectViewRegistry.register(ShapeObject.self) { obj, isSelected, vm in
            AnyView(ShapeObjectView(object: obj, isSelected: isSelected, viewModel: vm))
        }
        ObjectViewRegistry.register(LineObject.self) { obj, isSelected, vm in
            AnyView(LineObjectView(object: obj, isSelected: isSelected, viewModel: vm))
        }
        ObjectViewRegistry.register(ImageObject.self) { obj, isSelected, vm in
            AnyView(ImageObjectView(object: obj, isSelected: isSelected, viewModel: vm))
        }

        // Export view factories
        ObjectViewRegistry.registerExport(TextObject.self) { obj in
            AnyView(ExportTextObjectView(object: obj))
        }
        ObjectViewRegistry.registerExport(ShapeObject.self) { obj in
            AnyView(ExportShapeObjectView(object: obj))
        }
        ObjectViewRegistry.registerExport(LineObject.self) { obj in
            AnyView(ExportLineObjectView(object: obj))
        }
        ObjectViewRegistry.registerExport(ImageObject.self) { obj in
            AnyView(ExportImageObjectView(object: obj))
        }

        // Codable object registrations
        CodableObjectRegistry.register(TextObject.self, discriminator: "text")
        CodableObjectRegistry.register(ShapeObject.self, discriminator: "shape")
        CodableObjectRegistry.register(LineObject.self, discriminator: "line")
        CodableObjectRegistry.register(ImageObject.self, discriminator: "image")
    }
}
