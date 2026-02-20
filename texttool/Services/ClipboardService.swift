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
}
