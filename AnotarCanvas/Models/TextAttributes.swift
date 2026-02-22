//
//  TextAttributes.swift
//  AnotarCanvas
//
//  Created by Claude on 2/18/26.
//

import SwiftUI

/// Font weight options for text
public enum FontWeight: String, Codable, Hashable, CaseIterable {
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
    public var swiftUIWeight: Font.Weight {
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
    public var nsWeight: NSFont.Weight {
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
public enum HorizontalTextAlignment: String, Codable, Hashable, CaseIterable {
    case leading
    case center
    case trailing

    /// Converts to SwiftUI TextAlignment
    public var swiftUIAlignment: TextAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    /// Converts to SwiftUI HorizontalAlignment
    public var horizontalAlignment: HorizontalAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    /// Converts to NSTextAlignment for AppKit
    public var nsAlignment: NSTextAlignment {
        switch self {
        case .leading: return .left
        case .center: return .center
        case .trailing: return .right
        }
    }
}

/// Vertical text alignment options
public enum VerticalTextAlignment: String, Codable, Hashable, CaseIterable {
    case top
    case center
    case bottom

    /// Converts to SwiftUI VerticalAlignment
    public var swiftUIAlignment: VerticalAlignment {
        switch self {
        case .top: return .top
        case .center: return .center
        case .bottom: return .bottom
        }
    }
}

/// Comprehensive text styling attributes
public struct TextAttributes: Codable, Hashable {
    /// Font family name (use "System" for system font)
    public var fontFamily: String

    /// Font size in points
    public var fontSize: CGFloat

    /// Font weight
    public var fontWeight: FontWeight

    /// Whether text is italicized
    public var isItalic: Bool

    /// Text color
    public var textColor: CodableColor

    /// Horizontal text alignment within container
    public var horizontalAlignment: HorizontalTextAlignment

    /// Vertical text alignment within container
    public var verticalAlignment: VerticalTextAlignment

    /// Default text attributes
    public static var `default`: TextAttributes {
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
    public init(
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
    public var isBold: Bool {
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
    public var color: Color {
        get { textColor.color }
        set { textColor = CodableColor(newValue) }
    }
}

// MARK: - Font Generation

public extension TextAttributes {
    /// Creates a SwiftUI Font from these attributes
    public var font: Font {
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
    public var nsFont: NSFont {
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
public struct CodableColor: Codable, Hashable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var opacity: Double

    public init(_ color: Color) {
        // Convert SwiftUI Color to NSColor to extract components
        let nsColor = NSColor(color).usingColorSpace(.deviceRGB) ?? NSColor.black
        self.red = Double(nsColor.redComponent)
        self.green = Double(nsColor.greenComponent)
        self.blue = Double(nsColor.blueComponent)
        self.opacity = Double(nsColor.alphaComponent)
    }

    public init(red: Double, green: Double, blue: Double, opacity: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
    }

    public var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }

    // Common colors
    public static var black: CodableColor { CodableColor(.black) }
    public static var white: CodableColor { CodableColor(.white) }
    public static var clear: CodableColor { CodableColor(.clear) }
}
