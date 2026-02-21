//
//  ObjectViewRegistry.swift
//  texttool
//

import SwiftUI

/// Central registry mapping concrete CanvasObject types to their SwiftUI view factories.
/// Adding a new object type only requires a registration call — no core view files need modification.
/// @MainActor ensures all dictionary mutations happen on the main thread.
@MainActor
enum ObjectViewRegistry {
    /// Interactive view factories keyed by the concrete type's ObjectIdentifier
    private static var factories: [ObjectIdentifier: (AnyCanvasObject, Bool, CanvasViewModel) -> AnyView] = [:]

    /// Export (non-interactive) view factories keyed by the concrete type's ObjectIdentifier
    private static var exportFactories: [ObjectIdentifier: (AnyCanvasObject) -> AnyView] = [:]

    /// Register an interactive view factory for a concrete CanvasObject type.
    static func register<T: CanvasObject>(
        _ type: T.Type,
        factory: @escaping (T, Bool, CanvasViewModel) -> AnyView
    ) {
        factories[ObjectIdentifier(type)] = { anyObj, isSelected, viewModel in
            guard let typed = anyObj.asType(T.self) else {
                return AnyView(EmptyView())
            }
            return factory(typed, isSelected, viewModel)
        }
    }

    /// Register an export view factory for a concrete CanvasObject type.
    static func registerExport<T: CanvasObject>(
        _ type: T.Type,
        factory: @escaping (T) -> AnyView
    ) {
        exportFactories[ObjectIdentifier(type)] = { anyObj in
            guard let typed = anyObj.asType(T.self) else {
                return AnyView(EmptyView())
            }
            return factory(typed)
        }
    }

    /// Look up and create the interactive view for a given object.
    static func view(for object: AnyCanvasObject, isSelected: Bool, viewModel: CanvasViewModel) -> AnyView {
        guard let factory = factories[object.underlyingTypeId] else {
            return AnyView(EmptyView())
        }
        return factory(object, isSelected, viewModel)
    }

    /// Look up and create the export view for a given object.
    static func exportView(for object: AnyCanvasObject) -> AnyView {
        guard let factory = exportFactories[object.underlyingTypeId] else {
            return AnyView(EmptyView())
        }
        return factory(object)
    }
}
