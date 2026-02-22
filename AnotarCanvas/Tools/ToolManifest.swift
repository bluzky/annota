//
//  ToolManifest.swift
//  texttool
//
//  A ToolManifest bundles a CanvasTool together with all the registrations
//  its produced object type requires: interactive view, export view, and
//  clipboard (Codable) support.  Registering a manifest with
//  ToolRegistry.register(_:) performs all four registrations in one call,
//  making it impossible to add a tool and forget any of the steps.
//
//  Tools that don't produce a new object type (SelectTool, HandTool, ArrowTool)
//  are registered with ToolRegistry.register(_: any CanvasTool) directly.
//
//  Object types that have no dedicated tool (ImageObject) use ObjectManifest<Obj>
//  to cover the view and codable sides without a tool entry.
//

import SwiftUI

// MARK: - ToolManifest

/// Bundles a CanvasTool with the view and codable registrations for the object
/// type it produces.
public struct ToolManifest<Obj: CopyableCanvasObject> {
    public let tool: any CanvasTool
    public let discriminator: String
    public let interactiveView: @MainActor (Obj, Bool, CanvasViewModel) -> AnyView
    public let exportView: @MainActor (Obj) -> AnyView
}

// MARK: - ObjectManifest

/// View and codable registrations for an object type that has no dedicated tool
/// (e.g. ImageObject, which is inserted via paste rather than a toolbar tool).
public struct ObjectManifest<Obj: CopyableCanvasObject> {
    public let discriminator: String
    public let interactiveView: @MainActor (Obj, Bool, CanvasViewModel) -> AnyView
    public let exportView: @MainActor (Obj) -> AnyView
}
