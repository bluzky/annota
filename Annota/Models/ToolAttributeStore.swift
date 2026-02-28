//
//  ToolAttributeStore.swift
//  Annota
//
//  Application-layer storage for per-tool attributes.
//  Remembers last-used stroke, fill, font, etc. across tool switches.
//  Tools in the same category share one attribute bucket.
//

import SwiftUI
import Combine
import AnotarCanvas

@MainActor
class ToolAttributeStore: ObservableObject {
    /// Per-category attribute storage
    @Published var toolAttributes: [String: ObjectAttributes] = [:]

    /// Suppress persist-back when sync originates from the store
    var suppressPersist = false

    static let defaultAttributes: ObjectAttributes = [
        ObjectAttributes.strokeColor: Color.black,
        ObjectAttributes.strokeWidth: 2.0 as CGFloat,
        ObjectAttributes.strokeStyle: StrokeStyleType.solid,
        ObjectAttributes.fillColor: Color.white,
        ObjectAttributes.fillOpacity: 1.0 as CGFloat,
        ObjectAttributes.textColor: Color.black,
        ObjectAttributes.fontSize: 16.0 as CGFloat,
        ObjectAttributes.fontFamily: "System"
    ]

    /// Per-tool default overrides (merged on top of defaultAttributes)
    static let toolDefaultOverrides: [String: ObjectAttributes] = [
        "tool:pencil": [ObjectAttributes.strokeWidth: 3.0 as CGFloat]
    ]

    // MARK: - Key Resolution

    /// Resolve the storage key for a tool.
    /// Shape tools share one bucket; drawing tools (line, arrow, pencil) each get their own.
    func attributeKey(for tool: DrawingTool) -> String {
        if let resolved = ToolRegistry.shared.tool(for: tool) {
            switch resolved.category {
            case .shape:
                return "category:\(resolved.category.rawValue)"
            default:
                return "tool:\(tool.id)"
            }
        }
        return tool.id
    }

    // MARK: - Read

    /// Get the stored attributes for a tool (falls back to defaults with per-tool overrides)
    func attributes(for tool: DrawingTool) -> ObjectAttributes {
        let key = attributeKey(for: tool)
        if let stored = toolAttributes[key] {
            return stored
        }
        // Merge per-tool overrides on top of shared defaults
        if let overrides = Self.toolDefaultOverrides[key] {
            return Self.defaultAttributes.merging(overrides) { _, new in new }
        }
        return Self.defaultAttributes
    }

    // MARK: - Write

    /// Update a single attribute for a tool
    func updateAttribute(for tool: DrawingTool, key: String, value: Any) {
        let storageKey = attributeKey(for: tool)
        var attrs = toolAttributes[storageKey] ?? Self.defaultAttributes
        attrs[key] = value
        toolAttributes[storageKey] = attrs
    }

    /// Update a custom attribute within the customAttributes namespace
    func updateCustomAttribute(for tool: DrawingTool, key: String, value: Any) {
        let storageKey = attributeKey(for: tool)
        var attrs = toolAttributes[storageKey] ?? Self.defaultAttributes
        var customAttrs = (attrs[ObjectAttributes.customAttributes] as? [String: Any]) ?? [:]
        customAttrs[key] = value
        attrs[ObjectAttributes.customAttributes] = customAttrs
        toolAttributes[storageKey] = attrs
    }

    /// Get a custom attribute value with a default
    func getCustomAttribute<T>(for tool: DrawingTool, key: String, default defaultValue: T) -> T {
        let attrs = attributes(for: tool)
        let customAttrs = (attrs[ObjectAttributes.customAttributes] as? [String: Any]) ?? [:]
        return customAttrs[key] as? T ?? defaultValue
    }

    /// Get a custom attribute value (optional)
    func getCustomAttribute<T>(for tool: DrawingTool, key: String) -> T? {
        let attrs = attributes(for: tool)
        let customAttrs = (attrs[ObjectAttributes.customAttributes] as? [String: Any]) ?? [:]
        return customAttrs[key] as? T
    }

    // MARK: - Sync

    /// Push current tool's attributes into the view model
    func sync(to viewModel: CanvasViewModel) {
        suppressPersist = true
        viewModel.currentToolAttributes = attributes(for: viewModel.selectedTool)
        // Reset after the current run loop so onReceive handlers see the flag
        DispatchQueue.main.async { [weak self] in
            self?.suppressPersist = false
        }
    }

    /// Persist the view model's current attributes back into the store.
    /// Call this after framework-side controls (e.g. ArrowToolControls) mutate
    /// viewModel.currentToolAttributes directly.
    func persist(from viewModel: CanvasViewModel) {
        guard !suppressPersist else { return }
        let storageKey = attributeKey(for: viewModel.selectedTool)
        toolAttributes[storageKey] = viewModel.currentToolAttributes
    }
}
