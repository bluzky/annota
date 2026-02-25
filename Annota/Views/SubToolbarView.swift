//
//  SubToolbarView.swift
//  Annota
//
//  Context-sensitive toolbar below main toolbar
//  Shows selection attributes when objects are selected, tool attributes otherwise
//

import SwiftUI
import AnotarCanvas

private let availableFontFamilies = [
    "System", "Helvetica Neue", "Times New Roman", "Courier New", "Georgia", "Arial", "Menlo", "Comic Sans MS"
]

// Preset values for font size input
private let fontSizePresets: [CGFloat] = [8, 10, 12, 14, 16, 18, 20, 24, 28, 32, 36, 48, 64, 72, 96, 120]

// Preset values for stroke width input
private let strokeWidthPresets: [CGFloat] = [1, 2, 3, 4, 5, 6, 8, 10, 12, 16, 20]

/// Simplified stroke style cases for picker UI (avoids associated-value issues with Picker)
private enum StrokeStyleOption: String, CaseIterable, Identifiable {
    case solid = "Solid"
    case dashed = "Dashed"
    case dotted = "Dotted"

    var id: String { rawValue }

    var strokeStyleType: StrokeStyleType {
        switch self {
        case .solid: return .solid
        case .dashed: return .defaultDashed
        case .dotted: return .dotted
        }
    }

    init(from type: StrokeStyleType) {
        switch type {
        case .solid: self = .solid
        case .dashed: self = .dashed
        case .dotted: self = .dotted
        }
    }
}

struct SubToolbarView: View {
    @ObservedObject var viewModel: CanvasViewModel
    @ObservedObject var toolRegistry: ToolRegistry
    @ObservedObject var attributeStore: ToolAttributeStore
    @Binding var lastShapeTool: DrawingTool

    var body: some View {
        HStack(spacing: 16) {
            if viewModel.selectionState.hasSelection {
                selectionControls
            } else {
                toolControls
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }

    // Check if current tool has relevant attributes to display
    private var hasRelevantToolControls: Bool {
        let tool = toolRegistry.tool(for: viewModel.selectedTool)
        return tool?.category == .shape || tool?.category == .drawing || tool?.category == .annotation
    }

    // MARK: - Selection Controls

    @ViewBuilder
    private var selectionControls: some View {
        let capabilities = viewModel.cachedSelectionCapabilities
        let attrs = viewModel.cachedSelectionAttributes
        let objectCount = viewModel.selectionState.selectedIds.count

        if capabilities.canStroke {
            strokeControls(attributes: attrs)
            Divider().frame(height: 20)
        }

        if capabilities.canFill {
            fillControls(attributes: attrs)
            Divider().frame(height: 20)
        }

        if capabilities.canEditText {
            selectionTextControls(attributes: attrs)
            Divider().frame(height: 20)
        }

        // Arrangement controls: z-order + alignment/distribution
        arrangeControls(objectCount: objectCount)
    }

    @ViewBuilder
    private func strokeControls(attributes: ObjectAttributes) -> some View {
        // Color picker - always shown with first stroke color
        let strokeColor = attributes["strokeColor"] as? Color ?? .black
        ColorPresetPicker(selection: Binding(
            get: { strokeColor },
            set: { viewModel.updateSelected([ObjectAttributes.strokeColor: $0]) }
        ))
        .tooltip("Stroke Color")

        // Width input - always shown with first stroke width
        let strokeWidth = attributes["strokeWidth"] as? CGFloat ?? 2.0
        ValueInputView(
            value: strokeWidth,
            min: 1, max: 30,
            presets: strokeWidthPresets,
            onChange: { viewModel.updateSelected([ObjectAttributes.strokeWidth: $0]) }
        )
        .tooltip("Stroke Width")

        // Stroke style picker - always shown with first stroke style
        let strokeStyle = attributes[ObjectAttributes.strokeStyle] as? StrokeStyleType ?? .solid
        let currentOption = StrokeStyleOption(from: strokeStyle)
        Menu {
            ForEach(StrokeStyleOption.allCases) { option in
                Button(action: {
                    DispatchQueue.main.async {
                        viewModel.updateSelected([ObjectAttributes.strokeStyle: option.strokeStyleType])
                    }
                }) {
                    if option == currentOption {
                        Label(option.rawValue, systemImage: "checkmark")
                    } else {
                        Text(option.rawValue)
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text(currentOption.rawValue)
                    .font(.body)
                    .frame(minWidth: 50)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .tooltip("Stroke Style")
    }

    @ViewBuilder
    private func fillControls(attributes: ObjectAttributes) -> some View {
        // Fill color picker - always shown with first fill color
        let fillColor = attributes["fillColor"] as? Color ?? .white
        ColorPresetPicker(selection: Binding(
            get: { fillColor },
            set: { viewModel.updateSelected([ObjectAttributes.fillColor: $0]) }
        ))
        .tooltip("Fill Color")

        // Fill opacity slider - always shown with first fill opacity
        let fillOpacity = attributes["fillOpacity"] as? CGFloat ?? 1.0
        Slider(value: Binding(
            get: { fillOpacity },
            set: { viewModel.updateSelected([ObjectAttributes.fillOpacity: $0]) }
        ), in: 0...1)
        .frame(width: 80)
        .tooltip("Fill Opacity")

        Text("\(Int(fillOpacity * 100))%")
            .font(.caption)
            .frame(width: 35)
    }

    @ViewBuilder
    private func selectionTextControls(attributes: ObjectAttributes) -> some View {
        // Font family picker - always shown with first font family
        let fontFamily = attributes[ObjectAttributes.fontFamily] as? String ?? "System"
        Menu {
            ForEach(availableFontFamilies, id: \.self) { family in
                Button(action: {
                    DispatchQueue.main.async {
                        viewModel.updateSelected([ObjectAttributes.fontFamily: family])
                    }
                }) {
                    if family == fontFamily {
                        Label(family, systemImage: "checkmark")
                            .font(family == "System" ? .body : .custom(family, size: NSFont.systemFontSize)).fontWeight(.regular)
                    } else {
                        Text(family)
                            .font(family == "System" ? .body : .custom(family, size: NSFont.systemFontSize)).fontWeight(.regular)
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text("Font")
                    .font(fontFamily == "System" ? .body : .custom(fontFamily, size: NSFont.systemFontSize)).fontWeight(.regular)
                    .frame(minWidth: 40)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .tooltip("Font Family")

        // Font size input - always shown with first font size
        let fontSize = attributes[ObjectAttributes.fontSize] as? CGFloat ?? 16.0
        ValueInputView(
            value: fontSize,
            min: 8, max: 200,
            presets: fontSizePresets,
            onChange: { viewModel.updateSelected([ObjectAttributes.fontSize: $0]) }
        )
        .tooltip("Font Size")

        // Text color picker - always shown with first text color
        let textColor = attributes[ObjectAttributes.textColor] as? Color ?? .black
        ColorPresetPicker(selection: Binding(
            get: { textColor },
            set: { viewModel.updateSelected([ObjectAttributes.textColor: $0]) }
        ))
        .tooltip("Text Color")
    }

    private var toolFontFamily: String {
        attributeStore.attributes(for: viewModel.selectedTool)[ObjectAttributes.fontFamily] as? String ?? "System"
    }

    @ViewBuilder
    private func toolTextControls(attrs: ObjectAttributes) -> some View {
        // Font family picker
        Menu {
            ForEach(availableFontFamilies, id: \.self) { family in
                Button(action: {
                    DispatchQueue.main.async {
                        updateToolAttr(key: ObjectAttributes.fontFamily, value: family)
                    }
                }) {
                    if family == toolFontFamily {
                        Label(family, systemImage: "checkmark")
                            .font(family == "System" ? .body : .custom(family, size: NSFont.systemFontSize)).fontWeight(.regular)
                    } else {
                        Text(family)
                            .font(family == "System" ? .body : .custom(family, size: NSFont.systemFontSize)).fontWeight(.regular)
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text("Font")
                    .font(toolFontFamily == "System" ? .body : .custom(toolFontFamily, size: NSFont.systemFontSize)).fontWeight(.regular)
                    .frame(minWidth: 40)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .id(toolFontFamily)
        .tooltip("Font Family")

        // Font size input with presets and direct entry
        ValueInputView(
            value: attrs[ObjectAttributes.fontSize] as? CGFloat ?? 16.0,
            min: 8, max: 200,
            presets: fontSizePresets,
            onChange: { updateToolAttr(key: ObjectAttributes.fontSize, value: $0) }
        )
        .tooltip("Font Size")

        // Text color picker
        ColorPresetPicker(selection: Binding(
            get: { attrs[ObjectAttributes.textColor] as? Color ?? .black },
            set: { updateToolAttr(key: ObjectAttributes.textColor, value: $0) }
        ))
        .tooltip("Text Color")
    }

    @ViewBuilder
    private func arrangeControls(objectCount: Int) -> some View {
        // All arrangement controls in one flat HStack with equal spacing
        Button(action: { viewModel.bringToFront() }) {
            Image(systemName: "square.3.layers.3d.top.filled")
                .font(.caption)
        }
        .buttonStyle(.plain)
        .tooltip("Bring to Front")

        Button(action: { viewModel.sendToBack() }) {
            Image(systemName: "square.3.layers.3d.bottom.filled")
                .font(.caption)
        }
        .buttonStyle(.plain)
        .tooltip("Send to Back")

        Button(action: { viewModel.bringForward() }) {
            Image(systemName: "square.2.layers.3d.top.filled")
                .font(.caption)
        }
        .buttonStyle(.plain)
        .tooltip("Bring Forward")

        Button(action: { viewModel.sendBackward() }) {
            Image(systemName: "square.2.layers.3d.bottom.filled")
                .font(.caption)
        }
        .buttonStyle(.plain)
        .tooltip("Send Backward")

        // Align menu — disabled when < 2 objects selected
        Menu {
            ForEach(AlignmentAction.allCases, id: \.self) { action in
                Button(action: { viewModel.alignSelected(action) }) {
                    Label(action.title, systemImage: action.systemImage)
                }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "align.horizontal.center")
                    .font(.caption)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .disabled(objectCount < 2)
        .tooltip("Align")

        // Distribute menu — disabled when < 3 objects selected
        Menu {
            ForEach(DistributionAction.allCases, id: \.self) { action in
                Button(action: { viewModel.distributeSelected(action) }) {
                    Label(action.title, systemImage: action.systemImage)
                }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "distribute.horizontal.center")
                    .font(.caption)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .disabled(objectCount < 3)
        .tooltip("Distribute")
    }

    // MARK: - Tool Controls

    @ViewBuilder
    private var toolControls: some View {
        let tool = toolRegistry.tool(for: viewModel.selectedTool)
        let attrs = attributeStore.attributes(for: viewModel.selectedTool)

        // Shape tools - show shape selector + stroke + fill + text controls
        if tool?.category == .shape {
            ShapePickerStrip(viewModel: viewModel, lastShapeTool: $lastShapeTool)
            Divider().frame(height: 20)

            ColorPresetPicker(selection: Binding(
                get: { attrs[ObjectAttributes.strokeColor] as? Color ?? .black },
                set: { updateToolAttr(key: ObjectAttributes.strokeColor, value: $0) }
            ))
            .tooltip("Stroke Color")

            ValueInputView(
                value: attrs[ObjectAttributes.strokeWidth] as? CGFloat ?? 2.0,
                min: 1, max: 30,
                presets: strokeWidthPresets,
                onChange: { updateToolAttr(key: ObjectAttributes.strokeWidth, value: $0) }
            )
            .tooltip("Stroke Width")

            strokeStyleMenu(currentStyle: attrs[ObjectAttributes.strokeStyle] as? StrokeStyleType ?? .solid) { option in
                updateToolAttr(key: ObjectAttributes.strokeStyle, value: option.strokeStyleType)
            }
            .tooltip("Stroke Style")

            Divider().frame(height: 20)

            ColorPresetPicker(selection: Binding(
                get: { attrs[ObjectAttributes.fillColor] as? Color ?? .white },
                set: { updateToolAttr(key: ObjectAttributes.fillColor, value: $0) }
            ))
            .tooltip("Fill Color")

            Slider(value: Binding(
                get: { attrs[ObjectAttributes.fillOpacity] as? CGFloat ?? 1.0 },
                set: { updateToolAttr(key: ObjectAttributes.fillOpacity, value: $0) }
            ), in: 0...1)
            .frame(width: 80)
            .tooltip("Fill Opacity")

            Text("\(Int((attrs[ObjectAttributes.fillOpacity] as? CGFloat ?? 1.0) * 100))%")
                .font(.caption)
                .frame(width: 35)

            Divider().frame(height: 20)
            toolTextControls(attrs: attrs)
        }
        // Annotation tools (Text) - show only text controls
        else if tool?.category == .annotation {
            toolTextControls(attrs: attrs)
        }
        // Line tools - show only stroke controls
        else if tool?.category == .drawing {
            ColorPresetPicker(selection: Binding(
                get: { attrs[ObjectAttributes.strokeColor] as? Color ?? .black },
                set: { updateToolAttr(key: ObjectAttributes.strokeColor, value: $0) }
            ))
            .tooltip("Stroke Color")

            ValueInputView(
                value: attrs[ObjectAttributes.strokeWidth] as? CGFloat ?? 2.0,
                min: 1, max: 30,
                presets: strokeWidthPresets,
                onChange: { updateToolAttr(key: ObjectAttributes.strokeWidth, value: $0) }
            )
            .tooltip("Stroke Width")

            strokeStyleMenu(currentStyle: attrs[ObjectAttributes.strokeStyle] as? StrokeStyleType ?? .solid) { option in
                updateToolAttr(key: ObjectAttributes.strokeStyle, value: option.strokeStyleType)
            }
            .tooltip("Stroke Style")
        }

        // Tool-provided custom controls
        if let customControls = tool?.customToolControls(viewModel: viewModel) {
            Divider().frame(height: 20)
            customControls
        }
    }

    // MARK: - Helpers

    /// Update a tool attribute in the store and sync to the view model
    private func updateToolAttr(key: String, value: Any) {
        attributeStore.updateAttribute(for: viewModel.selectedTool, key: key, value: value)
        attributeStore.sync(to: viewModel)
    }

    @ViewBuilder
    private func strokeStyleMenu(currentStyle: StrokeStyleType, onSelect: @escaping (StrokeStyleOption) -> Void) -> some View {
        let current = StrokeStyleOption(from: currentStyle)
        Menu {
            ForEach(StrokeStyleOption.allCases) { option in
                Button(action: {
                    DispatchQueue.main.async { onSelect(option) }
                }) {
                    if option == current {
                        Label(option.rawValue, systemImage: "checkmark")
                    } else {
                        Text(option.rawValue)
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text(current.rawValue)
                    .font(.body)
                    .frame(minWidth: 50)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}
