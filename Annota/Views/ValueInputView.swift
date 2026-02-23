//
//  ValueInputView.swift
//  Annota
//
//  A reusable input component for numeric values with preset dropdown.
//  Allows direct numeric entry (TextField) or selection from presets.
//

import SwiftUI

struct ValueInputView: View {
    let value: CGFloat
    let min: CGFloat
    let max: CGFloat
    let presets: [CGFloat]
    let suffix: String              // e.g., "pt"
    let formatAsInteger: Bool       // true => "16pt", false => "1.5pt"
    let onChange: (CGFloat) -> Void

    @State private var editText: String
    @FocusState private var isFieldFocused: Bool

    init(value: CGFloat, min: CGFloat = 1, max: CGFloat = 200, presets: [CGFloat] = [], suffix: String = "pt", formatAsInteger: Bool = true, onChange: @escaping (CGFloat) -> Void) {
        self.value = value
        self.min = min
        self.max = max
        self.presets = presets
        self.suffix = suffix
        self.formatAsInteger = formatAsInteger
        self.onChange = onChange
        self._editText = State(initialValue: Self.formatValueForDisplay(value: value, formatAsInteger: formatAsInteger, suffix: suffix))
    }

    var body: some View {
        HStack(spacing: 0) {
            TextField("", text: $editText)
                .textFieldStyle(.plain)
                .font(.body)
                .frame(width: 40, alignment: .trailing)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .focused($isFieldFocused)
                .onExitCommand(perform: discardEdit)
                .onSubmit { commitEdit() }
                .onChange(of: isFieldFocused) { _, focused in
                    if !focused {
                        commitEdit()
                    }
                }
                .onChange(of: value) { _, newValue in
                    if !isFieldFocused {
                        editText = Self.formatValueForDisplay(value: newValue, formatAsInteger: formatAsInteger, suffix: suffix)
                    }
                }

            // Vertical divider
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 1)
                .frame(height: 16)

            // Dropdown button for preset selection (only chevron)
            Menu {
                ForEach(presets, id: \.self) { preset in
                    Button(action: { selectPreset(preset) }) {
                        if preset == value {
                            Label(formatValue(preset), systemImage: "checkmark")
                        } else {
                            Text(formatValue(preset))
                        }
                    }
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                    .frame(width: 22, height: 24)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
        )
        .fixedSize(horizontal: true, vertical: true)
    }

    // MARK: - Formatting

    private func formatValue(_ val: CGFloat) -> String {
        if formatAsInteger {
            return "\(Int(val))\(suffix)"
        } else {
            if val.truncatingRemainder(dividingBy: 1) == 0 {
                return "\(Int(val))\(suffix)"
            } else {
                return String(format: "%.1f%@", val, suffix)
            }
        }
    }

    /// Format with suffix for display (e.g. "16pt")
    private static func formatValueForDisplay(value: CGFloat, formatAsInteger: Bool, suffix: String) -> String {
        return formatValueForEdit(value: value, formatAsInteger: formatAsInteger) + suffix
    }

    /// Format without suffix for editing (e.g. "16")
    private static func formatValueForEdit(value: CGFloat, formatAsInteger: Bool) -> String {
        if formatAsInteger {
            return "\(Int(value))"
        } else if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value))"
        } else {
            return String(format: "%.1f", value)
        }
    }

    // MARK: - Editing Actions

    private func commitEdit() {
        // Accept both "16" and "16pt"
        let cleaned = editText
            .replacingOccurrences(of: suffix, with: "")
            .trimmingCharacters(in: .whitespaces)
        guard let parsed = Double(cleaned), !cleaned.isEmpty else {
            editText = Self.formatValueForDisplay(value: value, formatAsInteger: formatAsInteger, suffix: suffix)
            return
        }
        let clamped = Swift.min(Swift.max(CGFloat(parsed), min), max)
        onChange(clamped)
        editText = Self.formatValueForDisplay(value: clamped, formatAsInteger: formatAsInteger, suffix: suffix)
    }

    private func discardEdit() {
        editText = Self.formatValueForDisplay(value: value, formatAsInteger: formatAsInteger, suffix: suffix)
        isFieldFocused = false
    }

    private func selectPreset(_ preset: CGFloat) {
        onChange(preset)
        editText = Self.formatValueForDisplay(value: preset, formatAsInteger: formatAsInteger, suffix: suffix)
    }
}
