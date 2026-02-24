//
//  SettingsWindowView.swift
//  Annota
//
//  Settings UI window (Cmd+,)
//

import SwiftUI

struct SettingsWindowView: View {
    @EnvironmentObject var settings: SettingsManager<AnnotaSettings>
    @State private var selectedSection: SettingsSection = .ui

    enum SettingsSection: String, CaseIterable, Identifiable {
        case ui = "UI"
        case canvas = "Canvas"
        case tools = "Tools"
        case keyBindings = "Key Bindings"
        case advanced = "Advanced"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .ui: return "paintbrush"
            case .canvas: return "doc.plaintext"
            case .tools: return "pencil.circle"
            case .keyBindings: return "keyboard"
            case .advanced: return "gearshape.2"
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            List(SettingsSection.allCases, selection: $selectedSection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .frame(width: 180)

            Divider()

            // Detail
            ScrollView {
                switch selectedSection {
                case .ui:
                    UISettingsTab()
                case .canvas:
                    CanvasSettingsTab()
                case .tools:
                    ToolsSettingsTab()
                case .keyBindings:
                    KeyBindingsTab()
                case .advanced:
                    AdvancedSettingsTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 600, height: 420)
    }
}

// MARK: - UI Settings Tab

struct UISettingsTab: View {
    @EnvironmentObject var settings: SettingsManager<AnnotaSettings>

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: settings.binding(for: \.ui.theme)) {
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                    Text("System").tag("system")
                }
                .pickerStyle(.segmented)
            }

            Section("Grid") {
                Toggle("Show Grid", isOn: settings.binding(for: \.ui.showGrid))
                HStack {
                    Text("Grid Spacing")
                    Spacer()
                    TextField("", value: settings.binding(for: \.ui.gridSpacing), format: .number)
                        .frame(width: 60)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Canvas Settings Tab

struct CanvasSettingsTab: View {
    @EnvironmentObject var settings: SettingsManager<AnnotaSettings>

    var body: some View {
        Form {
            Section("Zoom") {
                HStack {
                    Text("Default Zoom")
                    Spacer()
                    TextField("", value: settings.binding(for: \.canvas.defaultZoom), format: .number)
                        .frame(width: 60)
                        .multilineTextAlignment(.trailing)
                }

                HStack {
                    Text("Min Zoom")
                    Spacer()
                    TextField("", value: settings.binding(for: \.canvas.minZoom), format: .number)
                        .frame(width: 60)
                        .multilineTextAlignment(.trailing)
                }

                HStack {
                    Text("Max Zoom")
                    Spacer()
                    TextField("", value: settings.binding(for: \.canvas.maxZoom), format: .number)
                        .frame(width: 60)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section("Snapping") {
                Toggle("Snap to Grid", isOn: settings.binding(for: \.canvas.snapToGrid))
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Tools Settings Tab

struct ToolsSettingsTab: View {
    @EnvironmentObject var settings: SettingsManager<AnnotaSettings>

    var body: some View {
        ScrollView {
            Form {
                Section("Shapes") {
                    HStack {
                        Text("Stroke Width")
                        Spacer()
                        TextField("", value: settings.binding(for: \.tools.shape.strokeWidth), format: .number)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing
                            )
                    }

                    ColorRow(
                        label: "Stroke Color",
                        hex: settings.binding(for: \.tools.shape.strokeColor)
                    )

                    ColorRow(
                        label: "Fill Color",
                        hex: settings.binding(for: \.tools.shape.fillColor)
                    )
                }

                Section("Lines") {
                    HStack {
                        Text("Stroke Width")
                        Spacer()
                        TextField("", value: settings.binding(for: \.tools.line.strokeWidth), format: .number)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                    }

                    ColorRow(
                        label: "Stroke Color",
                        hex: settings.binding(for: \.tools.line.strokeColor)
                    )
                }

                Section("Text") {
                    HStack {
                        Text("Font Size")
                        Spacer()
                        TextField("", value: settings.binding(for: \.tools.text.fontSize), format: .number)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                    }

                    ColorRow(
                        label: "Text Color",
                        hex: settings.binding(for: \.tools.text.textColor)
                    )
                }

                Section("Arrows") {
                    HStack {
                        Text("Stroke Width")
                        Spacer()
                        TextField("", value: settings.binding(for: \.tools.arrow.strokeWidth), format: .number)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                    }

                    ColorRow(
                        label: "Stroke Color",
                        hex: settings.binding(for: \.tools.arrow.strokeColor)
                    )
                }
            }
            .formStyle(.grouped)
        }
    }
}

// MARK: - Color Row

struct ColorRow: View {
    let label: String
    @Binding var hex: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            HStack(spacing: 8) {
                Text(hex)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: hex) ?? .gray)
                    .frame(width: 24, height: 24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                    )
            }
        }
    }
}

// MARK: - Key Row

struct KeyRow: View {
    let label: String
    @Binding var key: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("", text: $key)
                .frame(width: key.contains("+") ? 100 : 40)
                .multilineTextAlignment(.center)
                .font(.system(.body, design: .monospaced))
        }
    }
}

// MARK: - Key Bindings Tab

struct KeyBindingsTab: View {
    @EnvironmentObject var settings: SettingsManager<AnnotaSettings>

    var body: some View {
        ScrollView {
            Form {
                Section("Tool Quick Keys") {
                    KeyRow(label: "Select", key: settings.binding(for: \.toolKeys.select))
                    KeyRow(label: "Hand", key: settings.binding(for: \.toolKeys.hand))
                    KeyRow(label: "Text", key: settings.binding(for: \.toolKeys.text))
                    KeyRow(label: "Rectangle", key: settings.binding(for: \.toolKeys.rectangle))
                    KeyRow(label: "Oval", key: settings.binding(for: \.toolKeys.oval))
                    KeyRow(label: "Triangle", key: settings.binding(for: \.toolKeys.triangle))
                    KeyRow(label: "Diamond", key: settings.binding(for: \.toolKeys.diamond))
                    KeyRow(label: "Star", key: settings.binding(for: \.toolKeys.star))
                    KeyRow(label: "Line", key: settings.binding(for: \.toolKeys.line))
                    KeyRow(label: "Arrow", key: settings.binding(for: \.toolKeys.arrow))
                }

                Section("Command Shortcuts") {
                    KeyRow(label: "Delete Selected", key: settings.binding(for: \.commandKeys.deleteSelected))
                    KeyRow(label: "Copy", key: settings.binding(for: \.commandKeys.copy))
                    KeyRow(label: "Cut", key: settings.binding(for: \.commandKeys.cut))
                    KeyRow(label: "Paste", key: settings.binding(for: \.commandKeys.paste))
                    KeyRow(label: "Select All", key: settings.binding(for: \.commandKeys.selectAll))
                    KeyRow(label: "Undo", key: settings.binding(for: \.commandKeys.undo))
                    KeyRow(label: "Redo", key: settings.binding(for: \.commandKeys.redo))
                }
            }
            .formStyle(.grouped)
        }
    }
}

// MARK: - Advanced Settings Tab

struct AdvancedSettingsTab: View {
    @EnvironmentObject var settings: SettingsManager<AnnotaSettings>

    var body: some View {
        Form {
            Section("Configuration File") {
                HStack {
                    Text("Location")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(settings.fileURL.path)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button("Open in Editor") {
                        settings.openInEditor()
                    }

                    Button("Reveal in Finder") {
                        settings.revealInFinder()
                    }

                    Spacer()

                    Button("Reset to Defaults") {
                        settings.resetToDefaults()
                    }
                    .tint(.red)
                }
            }
        }
        .formStyle(.grouped)
    }
}
