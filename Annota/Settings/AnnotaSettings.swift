//
//  AnnotaSettings.swift
//  Annota
//
//  App-specific settings structs with Codable support
//

import SwiftUI

// MARK: - Root Settings

struct AnnotaSettings: Codable, Equatable {
    var version: Int = 1
    var ui: UISettings = .init()
    var canvas: CanvasSettings = .init()
    var tools: ToolDefaults = .init()
    var toolKeys: ToolKeySettings = .init()
    var commandKeys: CommandKeySettings = .init()

    enum CodingKeys: String, CodingKey {
        case version, ui, canvas, tools
        case toolKeys = "tool_keys"
        case commandKeys = "command_keys"
    }
}

// MARK: - UI Settings

struct UISettings: Codable, Equatable {
    var theme: String = "light"
    var showGrid: Bool = true
    var gridSpacing: Double = 20.0

    enum CodingKeys: String, CodingKey {
        case theme
        case showGrid = "show_grid"
        case gridSpacing = "grid_spacing"
    }
}

// MARK: - Canvas Settings

struct CanvasSettings: Codable, Equatable {
    var defaultZoom: Double = 1.0
    var minZoom: Double = 0.1
    var maxZoom: Double = 5.0
    var snapToGrid: Bool = false

    enum CodingKeys: String, CodingKey {
        case defaultZoom = "default_zoom"
        case minZoom = "min_zoom"
        case maxZoom = "max_zoom"
        case snapToGrid = "snap_to_grid"
    }
}

// MARK: - Tool Defaults

struct ToolDefaults: Codable, Equatable {
    var shape: ShapeDefaults = .init()
    var line: LineDefaults = .init()
    var text: TextDefaults = .init()
    var arrow: ArrowDefaults = .init()
}

struct ShapeDefaults: Codable, Equatable {
    var strokeColor: String = "#000000"
    var strokeWidth: Double = 2.0
    var fillColor: String = "#FFFFFF"

    enum CodingKeys: String, CodingKey {
        case strokeColor = "stroke_color"
        case strokeWidth = "stroke_width"
        case fillColor = "fill_color"
    }
}

struct LineDefaults: Codable, Equatable {
    var strokeColor: String = "#000000"
    var strokeWidth: Double = 2.0

    enum CodingKeys: String, CodingKey {
        case strokeColor = "stroke_color"
        case strokeWidth = "stroke_width"
    }
}

struct TextDefaults: Codable, Equatable {
    var fontSize: Double = 16.0
    var textColor: String = "#000000"

    enum CodingKeys: String, CodingKey {
        case fontSize = "font_size"
        case textColor = "text_color"
    }
}

struct ArrowDefaults: Codable, Equatable {
    var strokeColor: String = "#000000"
    var strokeWidth: Double = 2.0

    enum CodingKeys: String, CodingKey {
        case strokeColor = "stroke_color"
        case strokeWidth = "stroke_width"
    }
}

// MARK: - Tool Quick Keys (single key, no modifiers — switches active tool)

struct ToolKeySettings: Codable, Equatable {
    var select: String = "v"
    var hand: String = "h"
    var text: String = "t"
    var shape: String = "r"
    var line: String = "f"
    var arrow: String = "a"
    var pencil: String = "d"
}

// MARK: - Command Key Bindings (modifier + key — triggers an action)

struct CommandKeySettings: Codable, Equatable {
    var deleteSelected: String = "backspace"
    var copy: String = "cmd+c"
    var cut: String = "cmd+x"
    var paste: String = "cmd+v"
    var selectAll: String = "cmd+a"
    var undo: String = "cmd+z"
    var redo: String = "cmd+shift+z"

    // Arrangement
    var bringToFront: String = "cmd+shift+]"
    var bringForward: String = "cmd+]"
    var sendBackward: String = "cmd+["
    var sendToBack: String = "cmd+shift+["

    // Alignment
    var alignLeft: String = "cmd+shift+left"
    var alignRight: String = "cmd+shift+right"
    var alignTop: String = "cmd+shift+up"
    var alignBottom: String = "cmd+shift+down"
    var alignCenterH: String = "cmd+shift+h"
    var alignCenterV: String = "cmd+shift+v"

    // Distribution
    var distributeH: String = "cmd+ctrl+h"
    var distributeV: String = "cmd+ctrl+v"

    enum CodingKeys: String, CodingKey {
        case deleteSelected = "delete_selected"
        case copy, cut, paste
        case selectAll = "select_all"
        case undo, redo
        case bringToFront = "bring_to_front"
        case bringForward = "bring_forward"
        case sendBackward = "send_backward"
        case sendToBack = "send_to_back"
        case alignLeft = "align_left"
        case alignRight = "align_right"
        case alignTop = "align_top"
        case alignBottom = "align_bottom"
        case alignCenterH = "align_center_h"
        case alignCenterV = "align_center_v"
        case distributeH = "distribute_h"
        case distributeV = "distribute_v"
    }
}

// MARK: - Color Helpers

extension Color {
    /// Initialize from hex string (e.g., "#FF0000" or "FF0000")
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let length = hexSanitized.count
        let r, g, b: Double

        if length == 6 {
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
        } else {
            return nil
        }

        self.init(red: r, green: g, blue: b)
    }

    /// Convert to hex string (e.g., "#FF0000")
    func toHex() -> String? {
        guard let components = NSColor(self).usingColorSpace(.sRGB) else {
            return nil
        }

        let r = Int(components.redComponent * 255.0)
        let g = Int(components.greenComponent * 255.0)
        let b = Int(components.blueComponent * 255.0)

        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - Helpers for ToolAttributeStore

extension AnnotaSettings {
    var defaultShapeStrokeColor: Color {
        Color(hex: tools.shape.strokeColor) ?? .black
    }

    var defaultShapeFillColor: Color {
        Color(hex: tools.shape.fillColor) ?? .white
    }

    var defaultLineStrokeColor: Color {
        Color(hex: tools.line.strokeColor) ?? .black
    }

    var defaultTextColor: Color {
        Color(hex: tools.text.textColor) ?? .black
    }

    var defaultArrowStrokeColor: Color {
        Color(hex: tools.arrow.strokeColor) ?? .black
    }

    mutating func setShapeStrokeColor(_ color: Color) {
        if let hex = color.toHex() {
            tools.shape.strokeColor = hex
        }
    }

    mutating func setShapeFillColor(_ color: Color) {
        if let hex = color.toHex() {
            tools.shape.fillColor = hex
        }
    }

    mutating func setLineStrokeColor(_ color: Color) {
        if let hex = color.toHex() {
            tools.line.strokeColor = hex
        }
    }

    mutating func setTextColor(_ color: Color) {
        if let hex = color.toHex() {
            tools.text.textColor = hex
        }
    }

    mutating func setArrowStrokeColor(_ color: Color) {
        if let hex = color.toHex() {
            tools.arrow.strokeColor = hex
        }
    }
}
