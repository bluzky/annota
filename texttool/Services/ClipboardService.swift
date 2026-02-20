//
//  ClipboardService.swift
//  texttool
//

import AppKit
import Foundation

enum ClipboardService {
    private static let pasteboardType = NSPasteboard.PasteboardType("com.texttool.canvasobjects")

    static func copyObjects(_ objects: [CodableCanvasObject]) {
        guard !objects.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if let data = try? JSONEncoder().encode(objects) {
            pasteboard.setData(data, forType: pasteboardType)
        }
    }

    static func pasteObjects() -> [CodableCanvasObject]? {
        let pasteboard = NSPasteboard.general
        guard let data = pasteboard.data(forType: pasteboardType) else { return nil }
        return try? JSONDecoder().decode([CodableCanvasObject].self, from: data)
    }

    /// Attempts to paste image data from the system clipboard.
    /// Supports any image format macOS recognises (PNG, TIFF, JPEG, GIF, PDF, HEIC, WebP, …).
    /// - Returns: A tuple of (PNG-encoded data, pixel size) if an image is found, nil otherwise.
    static func pasteImageData() -> (data: Data, size: CGSize)? {
        let pasteboard = NSPasteboard.general

        // NSImage(pasteboard:) handles every image type the system supports
        guard let image = NSImage(pasteboard: pasteboard) else { return nil }

        // Prefer the best available pixel size: read from the pasteboard bitmap rep
        // to get actual pixel dimensions rather than point dimensions.
        let pixelSize: CGSize = bestPixelSize(from: pasteboard, fallback: image.size)

        guard let pngData = image.pngData() else { return nil }
        return (pngData, pixelSize)
    }

    /// Returns the pixel dimensions of the first bitmap rep on the pasteboard,
    /// falling back to the NSImage point size if no bitmap rep is available.
    private static func bestPixelSize(from pasteboard: NSPasteboard, fallback: CGSize) -> CGSize {
        // Walk known lossless types first so we get real pixel counts
        let preferredTypes: [NSPasteboard.PasteboardType] = [.png, .tiff]
        for type in preferredTypes {
            if let data = pasteboard.data(forType: type),
               let rep = NSBitmapImageRep(data: data) {
                return CGSize(width: rep.pixelsWide, height: rep.pixelsHigh)
            }
        }
        return fallback
    }
}

// MARK: - NSImage PNG Conversion

private extension NSImage {
    /// Convert NSImage to PNG data
    func pngData() -> Data? {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .png, properties: [:])
    }
}
