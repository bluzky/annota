//
//  SubToolbarView.swift
//  Annota
//
//  Context-sensitive toolbar below main toolbar
//  Shows selection attributes when objects are selected, tool attributes otherwise
//

import SwiftUI
import AnotarCanvas

struct SubToolbarView: View {
    @ObservedObject var viewModel: CanvasViewModel
    @ObservedObject var toolRegistry: ToolRegistry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.selectionState.hasSelection {
                selectionControls
            } else {
                toolControls
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        // Hide completely if nothing to show
        .opacity(hasContent ? 1 : 0)
        .frame(height: hasContent ? nil : 0)
    }

    // Check if there's any content to display
    private var hasContent: Bool {
        if viewModel.selectionState.hasSelection {
            return true
        }
        // Check if current tool has relevant attributes to display
        let tool = toolRegistry.tool(for: viewModel.selectedTool)
        return tool?.category == .shape || tool?.category == .drawing || tool?.category == .annotation
    }

    // Check if current tool has relevant attributes to display
    private var hasRelevantToolControls: Bool {
        let tool = toolRegistry.tool(for: viewModel.selectedTool)
        return tool?.category == .shape || tool?.category == .drawing || tool?.category == .annotation
    }

    // MARK: - Selection Controls

    @ViewBuilder
    private var selectionControls: some View {
        let capabilities = viewModel.selectionCapabilities
        let attrs = viewModel.getSelectionAttributes()

        Text("\(capabilities.objectCount) selected")
            .font(.caption)
            .foregroundColor(.secondary)

        Divider().frame(height: 20)

        if capabilities.canStroke {
            strokeControls(attributes: attrs)
            Divider().frame(height: 20)
        }

        if capabilities.canFill {
            fillControls(attributes: attrs)
            Divider().frame(height: 20)
        }

        zOrderControls

        Spacer()

        Button(action: { viewModel.deleteSelected() }) {
            Image(systemName: "trash")
                .foregroundColor(.red)
        }
        .buttonStyle(.plain)
        .help("Delete")
    }

    @ViewBuilder
    private func strokeControls(attributes: ObjectAttributes) -> some View {
        Label("Stroke", systemImage: "pencil.line")
            .font(.caption)
            .foregroundColor(.secondary)

        // Color picker - shows current or "Mixed"
        if let strokeColor = attributes["strokeColor"] as? Color {
            ColorPicker("", selection: Binding(
                get: { strokeColor },
                set: { viewModel.updateSelected([ObjectAttributes.strokeColor: $0]) }
            ))
            .labelsHidden()
            .frame(width: 40)
        } else {
            Text("Mixed")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 40)
        }

        // Width stepper - shows current or "Mixed"
        if let strokeWidth = attributes["strokeWidth"] as? CGFloat {
            Stepper(value: Binding(
                get: { strokeWidth },
                set: { viewModel.updateSelected([ObjectAttributes.strokeWidth: $0]) }
            ), in: 0...20, step: 0.5) {
                Text("\(Int(strokeWidth))pt")
                    .font(.caption)
                    .frame(width: 30)
            }
        } else {
            Text("Mixed")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func fillControls(attributes: ObjectAttributes) -> some View {
        Label("Fill", systemImage: "paintbrush.fill")
            .font(.caption)
            .foregroundColor(.secondary)

        if let fillColor = attributes["fillColor"] as? Color {
            ColorPicker("", selection: Binding(
                get: { fillColor },
                set: { viewModel.updateSelected([ObjectAttributes.fillColor: $0]) }
            ))
            .labelsHidden()
            .frame(width: 40)
        } else {
            Text("Mixed")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 40)
        }

        if let fillOpacity = attributes["fillOpacity"] as? CGFloat {
            Slider(value: Binding(
                get: { fillOpacity },
                set: { viewModel.updateSelected([ObjectAttributes.fillOpacity: $0]) }
            ), in: 0...1)
            .frame(width: 80)

            Text("\(Int(fillOpacity * 100))%")
                .font(.caption)
                .frame(width: 35)
        } else {
            Text("Mixed")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var zOrderControls: some View {
        HStack(spacing: 4) {
            Button(action: { viewModel.bringToFront() }) {
                Image(systemName: "square.3.layers.3d.top.filled")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .help("Bring to Front")

            Button(action: { viewModel.sendToBack() }) {
                Image(systemName: "square.3.layers.3d.bottom.filled")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .help("Send to Back")

            Button(action: { viewModel.bringForward() }) {
                Image(systemName: "square.3.layers.3d.top.stroked")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .help("Bring Forward")

            Button(action: { viewModel.sendBackward() }) {
                Image(systemName: "square.3.layers.3d.bottom.stroked")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .help("Send Backward")
        }
    }

    // MARK: - Tool Controls

    @ViewBuilder
    private var toolControls: some View {
        let tool = toolRegistry.tool(for: viewModel.selectedTool)
        let attrs = viewModel.currentToolAttributes

        // Shape and annotation tools
        if tool?.category == .shape || tool?.category == .annotation {
            Label("Stroke", systemImage: "pencil.line")
                .font(.caption)
                .foregroundColor(.secondary)

            ColorPicker("", selection: Binding(
                get: { attrs["strokeColor"] as? Color ?? .black },
                set: { viewModel.updateToolAttribute(key: ObjectAttributes.strokeColor, value: $0) }
            ))
            .labelsHidden()
            .frame(width: 40)

            Stepper(value: Binding(
                get: { attrs["strokeWidth"] as? CGFloat ?? 2.0 },
                set: { viewModel.updateToolAttribute(key: ObjectAttributes.strokeWidth, value: $0) }
            ), in: 0...20, step: 0.5) {
                Text("\(Int(attrs["strokeWidth"] as? CGFloat ?? 2.0))pt")
                    .font(.caption)
                    .frame(width: 30)
            }

            Divider().frame(height: 20)

            if tool?.category == .shape {
                Label("Fill", systemImage: "paintbrush.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ColorPicker("", selection: Binding(
                    get: { attrs["fillColor"] as? Color ?? .white },
                    set: { viewModel.updateToolAttribute(key: ObjectAttributes.fillColor, value: $0) }
                ))
                .labelsHidden()
                .frame(width: 40)

                Slider(value: Binding(
                    get: { attrs["fillOpacity"] as? CGFloat ?? 1.0 },
                    set: { viewModel.updateToolAttribute(key: ObjectAttributes.fillOpacity, value: $0) }
                ), in: 0...1)
                .frame(width: 80)

                Text("\(Int((attrs["fillOpacity"] as? CGFloat ?? 1.0) * 100))%")
                    .font(.caption)
                    .frame(width: 35)
            }
        }
        // Line tools
        else if tool?.category == .drawing {
            Label("Line", systemImage: "pencil.line")
                .font(.caption)
                .foregroundColor(.secondary)

            ColorPicker("", selection: Binding(
                get: { attrs["strokeColor"] as? Color ?? .black },
                set: { viewModel.updateToolAttribute(key: ObjectAttributes.strokeColor, value: $0) }
            ))
            .labelsHidden()
            .frame(width: 40)

            Stepper(value: Binding(
                get: { attrs["strokeWidth"] as? CGFloat ?? 2.0 },
                set: { viewModel.updateToolAttribute(key: ObjectAttributes.strokeWidth, value: $0) }
            ), in: 0...20, step: 0.5) {
                Text("\(Int(attrs["strokeWidth"] as? CGFloat ?? 2.0))pt")
                    .font(.caption)
                    .frame(width: 30)
            }
        }

        Spacer()
    }
}
