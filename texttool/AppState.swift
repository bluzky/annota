//
//  AppState.swift
//  texttool
//
//  Global singleton that bridges the CanvasViewModel into Commands,
//  working around the unreliability of @FocusedObject when AppKit views
//  (NSTextView etc.) hold first responder.
//

import Foundation
import AppKit
import UniformTypeIdentifiers

@MainActor
final class AppState {
    static let shared = AppState()
    private init() {}

    weak var canvasViewModel: CanvasViewModel?

    // MARK: - Export

    enum ExportFormat {
        case png, jpeg

        var fileType: NSBitmapImageRep.FileType {
            switch self {
            case .png: return .png
            case .jpeg: return .jpeg
            }
        }

        var fileExtension: String {
            switch self {
            case .png: return "png"
            case .jpeg: return "jpg"
            }
        }

        var contentType: UTType {
            switch self {
            case .png: return .png
            case .jpeg: return .jpeg
            }
        }
    }

    /// Called from Commands — renders the image immediately (while the view model
    /// is still accessible) and then defers the NSSavePanel until the menu runloop exits.
    func requestExport(format: ExportFormat) {
        print("[Export] requestExport called for format: \(format)")

        guard let viewModel = canvasViewModel else {
            print("[Export] ERROR: canvasViewModel is nil")
            return
        }
        guard let image = viewModel.renderToImage() else {
            print("[Export] ERROR: renderToImage returned nil")
            return
        }
        print("[Export] Image rendered: \(image.size)")

        // Use CFRunLoopPerformBlock to schedule panel creation in the default
        // run loop mode. This ensures we wait until the menu-tracking mode
        // has fully exited before creating AppKit panels (NSSavePanel crashes
        // if created while the menu run loop is still active).
        CFRunLoopPerformBlock(CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue) { [weak self] in
            self?.showSavePanel(image: image, format: format)
        }
        CFRunLoopWakeUp(CFRunLoopGetMain())
    }

    private func showSavePanel(image: NSImage, format: ExportFormat) {
        print("[Export] Creating NSSavePanel...")
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "canvas.\(format.fileExtension)"
        panel.allowedContentTypes = [format.contentType]
        panel.canCreateDirectories = true

        guard let window = NSApp.keyWindow else {
            print("[Export] ERROR: No key window")
            return
        }
        print("[Export] Presenting sheet on window: \(window)")

        panel.beginSheetModal(for: window) { [weak self] response in
            print("[Export] Sheet completed with response: \(response)")
            guard response == .OK, let url = panel.url else { return }
            do {
                try self?.writeImage(image, format: format, to: url)
                print("[Export] Successfully wrote to: \(url)")
            } catch {
                print("[Export] ERROR writing image: \(error)")
                let alert = NSAlert()
                alert.messageText = "Export Failed"
                alert.informativeText = error.localizedDescription
                alert.runModal()
            }
        }
    }

    private func writeImage(_ image: NSImage, format: ExportFormat, to url: URL) throws {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            throw ExportError.renderFailed
        }
        let properties: [NSBitmapImageRep.PropertyKey: Any] = format == .jpeg
            ? [.compressionFactor: 0.9]
            : [:]
        guard let data = bitmapRep.representation(using: format.fileType, properties: properties) else {
            throw ExportError.encodingFailed
        }
        try data.write(to: url, options: .atomic)
    }
}

private enum ExportError: LocalizedError {
    case renderFailed, encodingFailed
    var errorDescription: String? {
        switch self {
        case .renderFailed: return "Could not render the canvas to an image."
        case .encodingFailed: return "Could not encode the image data."
        }
    }
}
