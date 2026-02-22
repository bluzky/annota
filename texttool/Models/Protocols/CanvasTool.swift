//
//  CanvasTool.swift
//  texttool
//

import SwiftUI

/// Protocol that all canvas tools must implement.
/// Each tool encapsulates its own preview rendering, gesture handling, and object rendering.
/// A tool's identity is fully represented by its `toolType: DrawingTool` value;
/// the registry keys directly on `toolType.id` for O(1) lookup.
protocol CanvasTool {
    /// Tool metadata for UI rendering (icon, name, category, etc.)
    var metadata: ToolMetadata { get }

    /// The DrawingTool value that uniquely identifies this tool instance.
    var toolType: DrawingTool { get }

    /// Render preview during drag operation.
    /// Returns AnyView to allow heterogeneous tool dispatch via ToolRegistry.
    func renderPreview(
        start: CGPoint,
        current: CGPoint,
        viewModel: CanvasViewModel
    ) -> AnyView

    /// Handle drag gesture changed event
    func handleDragChanged(
        start: CGPoint,
        current: CGPoint,
        viewModel: CanvasViewModel
    )

    /// Finalize object creation when drag ends
    func handleDragEnded(
        start: CGPoint,
        end: CGPoint,
        viewModel: CanvasViewModel,
        shiftHeld: Bool
    )

    /// Handle click event (optional, default does nothing)
    func handleClick(
        at point: CGPoint,
        viewModel: CanvasViewModel,
        shiftHeld: Bool
    )
}

// MARK: - Default Implementations

extension CanvasTool {
    func handleClick(
        at point: CGPoint,
        viewModel: CanvasViewModel,
        shiftHeld: Bool
    ) {
        // Default: no-op for tools that don't need click handling
    }

    func renderPreview(
        start: CGPoint,
        current: CGPoint,
        viewModel: CanvasViewModel
    ) -> AnyView {
        AnyView(EmptyView())
    }

    func handleDragChanged(
        start: CGPoint,
        current: CGPoint,
        viewModel: CanvasViewModel
    ) {
        // Default: no-op
    }

    func handleDragEnded(
        start: CGPoint,
        end: CGPoint,
        viewModel: CanvasViewModel,
        shiftHeld: Bool
    ) {
        // Default: no-op
    }
}

// MARK: - ToolMetadata

/// Metadata describing a tool for UI purposes
struct ToolMetadata {
    let name: String
    let icon: String              // SF Symbol name
    let category: ToolCategory
    let cursorType: NSCursor
    let shortcutKey: String?      // Optional keyboard shortcut
}

// MARK: - ToolCategory

enum ToolCategory: String, CaseIterable {
    case selection    // Select, Hand
    case shape        // Rectangle, Circle, etc.
    case drawing      // Line, Arrow, Pencil, Highlighter
    case annotation   // Text, Note, Auto-number
    case navigation   // Hand, Zoom
}
