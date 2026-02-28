//
//  CanvasTool.swift
//  AnotarCanvas
//

import SwiftUI

/// Protocol that all canvas tools must implement.
/// Each tool encapsulates its own preview rendering, gesture handling, and object rendering.
/// A tool's identity is fully represented by its `toolType: DrawingTool` value;
/// the registry keys directly on `toolType.id` for O(1) lookup.
public protocol CanvasTool {
    /// Tool name for debugging, logging, plugin identification
    var name: String { get }

    /// Category for functional grouping
    var category: ToolCategory { get }

    /// Cursor for visual feedback during drawing
    var cursor: NSCursor { get }

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

    /// Declares capabilities this tool supports (e.g., .labelText, .fill, .stroke).
    /// Third-party tools can declare custom capabilities using string literals.
    /// Used by SubToolbarView to dynamically show relevant attribute controls.
    var capabilities: Set<ToolCapability> { get }

    /// Optional: Tool provides custom controls for the sub-toolbar
    /// Return nil if the tool has no custom attributes
    /// Tools can use this to display their own SwiftUI controls
    func customToolControls(viewModel: CanvasViewModel) -> AnyView?
}

// MARK: - Default Implementations

public extension CanvasTool {
    /// Default capabilities for most tools (stroke, fill, label text)
    var capabilities: Set<ToolCapability> {
        [.stroke, .fill, .labelText]
    }

    func handleClick(
        at point: CGPoint,
        viewModel: CanvasViewModel,
        shiftHeld: Bool
    ) {
        // Default: no-op for tools that don't need click handling
    }

    func customToolControls(viewModel: CanvasViewModel) -> AnyView? {
        // Default: no custom controls
        return nil
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

    // MARK: - Convenience Capability Checks

    /// Check if this tool supports a specific capability
    func supports(_ capability: ToolCapability) -> Bool {
        capabilities.contains(capability)
    }
}

// MARK: - ToolCategory

public enum ToolCategory: String, CaseIterable {
    case selection    // Select, Hand
    case shape        // Rectangle, Circle, etc.
    case drawing      // Line, Arrow, Pencil, Highlighter
    case annotation   // Text, Note, Auto-number
    case navigation   // Hand, Zoom
}
