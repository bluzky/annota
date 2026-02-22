//
//  AppState.swift
//  Annota
//
//  Global singleton that bridges the CanvasViewModel into Commands,
//  working around the unreliability of @FocusedObject when AppKit views
//  (NSTextView etc.) hold first responder.
//

import Foundation
import AppKit
import UniformTypeIdentifiers
import os.log
import AnotarCanvas

private let exportLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Annota", category: "Export")

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
        exportLogger.debug("requestExport called for format: \(String(describing: format))")

        guard let viewModel = canvasViewModel else {
            exportLogger.error("canvasViewModel is nil")
            return
        }
        guard let image = viewModel.renderToImage() else {
            exportLogger.error("renderToImage returned nil")
            return
        }
        exportLogger.debug("Image rendered: \(image.size.debugDescription)")

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
        exportLogger.debug("Creating NSSavePanel...")
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "canvas.\(format.fileExtension)"
        panel.allowedContentTypes = [format.contentType]
        panel.canCreateDirectories = true

        guard let window = NSApp.keyWindow else {
            // No key window available — inform the user instead of silently dropping the export.
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Export Unavailable"
            alert.informativeText = "The canvas window could not be found. Please bring the app to the foreground and try again."
            alert.runModal()
            return
        }
        exportLogger.debug("Presenting sheet on window: \(window.debugDescription)")

        panel.beginSheetModal(for: window) { [weak self] response in
            exportLogger.debug("Sheet completed with response: \(response.rawValue)")
            guard response == .OK, let url = panel.url else { return }
            do {
                try self?.writeImage(image, format: format, to: url)
                exportLogger.debug("Successfully wrote to: \(url.path)")
            } catch {
                exportLogger.error("Error writing image: \(error.localizedDescription)")
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
