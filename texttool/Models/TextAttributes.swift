//
//  TextAttributes.swift
//  texttool
//
//  Created by Claude on 2/18/26.
//

import SwiftUI

/// Font weight options for text
enum FontWeight: String, Codable, Hashable, CaseIterable {
    case ultraLight
    case thin
    case light
    case regular
    case medium
    case semibold
    case bold
    case heavy
    case black

    /// Converts to SwiftUI Font.Weight
    var swiftUIWeight: Font.Weight {
        switch self {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        }
    }

    /// Converts to NSFont.Weight for AppKit
    var nsWeight: NSFont.Weight {
        switch self {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        }
    }
}

/// Horizontal text alignment options
enum HorizontalTextAlignment: String, Codable, Hashable, CaseIterable {
    case leading
    case center
    case trailing

    /// Converts to SwiftUI TextAlignment
    var swiftUIAlignment: TextAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    /// Converts to SwiftUI HorizontalAlignment
    var horizontalAlignment: HorizontalAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    /// Converts to NSTextAlignment for AppKit
    var nsAlignment: NSTextAlignment {
        switch self {
        case .leading: return .left
        case .center: return .center
        case .trailing: return .right
        }
    }
}

/// Vertical text alignment options
enum VerticalTextAlignment: String, Codable, Hashable, CaseIterable {
    case top
    case center
    case bottom

    /// Converts to SwiftUI VerticalAlignment
    var swiftUIAlignment: VerticalAlignment {
        switch self {
        case .top: return .top
        case .center: return .center
        case .bottom: return .bottom
        }
    }
}

/// Comprehensive text styling attributes
struct TextAttributes: Codable, Hashable {
    /// Font family name (use "System" for system font)
    var fontFamily: String

    /// Font size in points
    var fontSize: CGFloat

    /// Font weight
    var fontWeight: FontWeight

    /// Whether text is italicized
    var isItalic: Bool

    /// Text color
    var textColor: CodableColor

    /// Horizontal text alignment within container
    var horizontalAlignment: HorizontalTextAlignment

    /// Vertical text alignment within container
    var verticalAlignment: VerticalTextAlignment

    /// Default text attributes
    static var `default`: TextAttributes {
        TextAttributes(
            fontFamily: "System",
            fontSize: 16,
            fontWeight: .regular,
            isItalic: false,
            textColor: CodableColor(.black),
            horizontalAlignment: .center,
            verticalAlignment: .center
        )
    }

    /// Initialize with default values
    init(
        fontFamily: String = "System",
        fontSize: CGFloat = 16,
        fontWeight: FontWeight = .regular,
        isItalic: Bool = false,
        textColor: CodableColor = CodableColor(.black),
        horizontalAlignment: HorizontalTextAlignment = .center,
        verticalAlignment: VerticalTextAlignment = .center
    ) {
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.isItalic = isItalic
        self.textColor = textColor
        self.horizontalAlignment = horizontalAlignment
        self.verticalAlignment = verticalAlignment
    }

    // MARK: - Convenience Properties

    /// Returns true if font weight is bold or heavier
    var isBold: Bool {
        get {
            switch fontWeight {
            case .semibold, .bold, .heavy, .black:
                return true
            default:
                return false
            }
        }
        set {
            fontWeight = newValue ? .bold : .regular
        }
    }

    /// Returns the SwiftUI Color for text
    var color: Color {
        get { textColor.color }
        set { textColor = CodableColor(newValue) }
    }
}

// MARK: - Font Generation

extension TextAttributes {
    /// Creates a SwiftUI Font from these attributes
    var font: Font {
        var font: Font

        if fontFamily == "System" {
            font = .system(size: fontSize, weight: fontWeight.swiftUIWeight)
        } else {
            // Try to create a custom font, fall back to system if not found
            font = .custom(fontFamily, size: fontSize)
        }

        if isItalic {
            font = font.italic()
        }

        return font
    }

    /// Creates an NSFont from these attributes
    var nsFont: NSFont {
        let baseFont: NSFont

        if fontFamily == "System" {
            baseFont = NSFont.systemFont(ofSize: fontSize, weight: fontWeight.nsWeight)
        } else if let customFont = NSFont(name: fontFamily, size: fontSize) {
            baseFont = customFont
        } else {
            baseFont = NSFont.systemFont(ofSize: fontSize, weight: fontWeight.nsWeight)
        }

        if isItalic {
            let fontManager = NSFontManager.shared
            if let italicFont = fontManager.convert(baseFont, toHaveTrait: .italicFontMask) as NSFont? {
                return italicFont
            }
        }

        return baseFont
    }
}

// MARK: - Codable Color Wrapper

/// A Codable wrapper for SwiftUI Color
struct CodableColor: Codable, Hashable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double

    init(_ color: Color) {
        // Convert SwiftUI Color to NSColor to extract components
        let nsColor = NSColor(color).usingColorSpace(.deviceRGB) ?? NSColor.black
        self.red = Double(nsColor.redComponent)
        self.green = Double(nsColor.greenComponent)
        self.blue = Double(nsColor.blueComponent)
        self.opacity = Double(nsColor.alphaComponent)
    }

    init(red: Double, green: Double, blue: Double, opacity: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
    }

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }

    // Common colors
    static var black: CodableColor { CodableColor(.black) }
    static var white: CodableColor { CodableColor(.white) }
    static var clear: CodableColor { CodableColor(.clear) }
}
