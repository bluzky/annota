//
//  AutoGrowingTextView.swift
//  AnotarCanvas
//
//  Created by Flex on 12/11/25.
//

import SwiftUI
import AppKit

/// Resolve a font family name and size to an NSFont (regular weight).
/// "System" maps to the system font; other names use NSFontManager to get the regular variant.
private func resolveNSFont(family: String, size: CGFloat) -> NSFont {
    if family == "System" {
        return NSFont.systemFont(ofSize: size, weight: .regular)
    }
    let fm = NSFontManager.shared
    if let font = fm.font(withFamily: family, traits: [], weight: 5, size: size) {
        return font
    }
    return NSFont(name: family, size: size) ?? NSFont.systemFont(ofSize: size, weight: .regular)
}

struct AutoGrowingTextView: NSViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat
    var fontFamily: String = "System"
    var textColor: Color
    var onFocus: () -> Void
    var onSizeChange: ((CGSize) -> Void)?
    var scale: CGFloat = 1.0

    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()

        // Configure text view
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.font = resolveNSFont(family: fontFamily, size: fontSize)
        textView.textColor = NSColor(textColor)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainerInset = NSSize(width: 4 * scale, height: 4 * scale)
        textView.alignment = .left

        // Key settings for horizontal growth
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width, .height]

        // Set text container to not wrap
        if let container = textView.textContainer {
            container.widthTracksTextView = false
            container.heightTracksTextView = false
            container.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        }

        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: fontSize * 1.5)

        textView.string = text

        // Auto-focus on creation
        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }

        return textView
    }

    func updateNSView(_ textView: NSTextView, context: Context) {
        // NEVER update text while editing - this causes race conditions and lost keystrokes
        // The NSTextView is already updating itself via textDidChange
        if !context.coordinator.isEditing {
            // Only update text if it actually differs (e.g., external change)
            if textView.string != text {
                let selectedRange = textView.selectedRange()
                textView.string = text
                // Restore cursor position if valid
                if selectedRange.location <= text.count {
                    textView.setSelectedRange(selectedRange)
                }
            }
        }

        textView.font = resolveNSFont(family: fontFamily, size: fontSize)
        textView.textColor = NSColor(textColor)
        textView.textContainerInset = NSSize(width: 4 * scale, height: 4 * scale)

        // Update min size based on font size
        textView.minSize = NSSize(width: 0, height: fontSize * 1.5)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSTextView, context: Context) -> CGSize? {
        let textView = nsView
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        let insetPadding = 8 * scale

        if let container = textView.textContainer,
           let layoutManager = textView.layoutManager {
            let usedRect = layoutManager.usedRect(for: container)
            return CGSize(
                width: usedRect.width + insetPadding,
                height: max(fontSize * 1.5, usedRect.height + insetPadding)
            )
        }

        return CGSize(width: 10, height: fontSize * 1.5)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: AutoGrowingTextView
        var isEditing = false
        var lastReportedSize: CGSize = .zero

        init(_ parent: AutoGrowingTextView) {
            self.parent = parent
            super.init()
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }

            // Set editing flag to prevent updateNSView from interfering
            isEditing = true

            // Update binding - this triggers SwiftUI update
            parent.text = textView.string

            // Clear editing flag after a short delay to allow the update to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
                self?.isEditing = false
            }

            // Report size change only if it actually changed significantly
            if let container = textView.textContainer,
               let layoutManager = textView.layoutManager {
                layoutManager.ensureLayout(for: container)
                let usedRect = layoutManager.usedRect(for: container)
                let insetPadding = 8 * parent.scale
                let size = CGSize(
                    width: usedRect.width + insetPadding,
                    height: max(parent.fontSize * 1.5, usedRect.height + insetPadding)
                )
                // Only report if size changed by more than 1 point
                if abs(size.width - lastReportedSize.width) > 1 ||
                   abs(size.height - lastReportedSize.height) > 1 {
                    lastReportedSize = size
                    parent.onSizeChange?(size)
                }
            }
        }

        func textDidBeginEditing(_ notification: Notification) {
            parent.onFocus()
        }
    }
}

// MARK: - Constrained Width Text View (for shapes)

struct ConstrainedAutoGrowingTextView: NSViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat
    var fontFamily: String = "System"
    var textColor: Color
    var maxWidth: CGFloat
    var alignment: NSTextAlignment
    var onHeightChange: ((CGFloat) -> Void)?

    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()

        // Configure text view
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.font = resolveNSFont(family: fontFamily, size: fontSize)
        textView.textColor = NSColor(textColor)
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.alignment = alignment

        // Fixed width, grows vertically
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.height]

        // Set text container to wrap at maxWidth
        if let container = textView.textContainer {
            container.widthTracksTextView = true
            container.heightTracksTextView = false
            container.lineFragmentPadding = 0
            container.containerSize = NSSize(width: maxWidth - 8, height: CGFloat.greatestFiniteMagnitude)
        }

        textView.maxSize = NSSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: maxWidth - 8, height: fontSize * 1.5)

        textView.string = text

        // Auto-focus on creation
        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }

        return textView
    }

    func updateNSView(_ textView: NSTextView, context: Context) {
        // NEVER update text while editing - mirrors AutoGrowingTextView guard to prevent
        // lost keystrokes when SwiftUI re-renders during active typing.
        if !context.coordinator.isEditing {
            if textView.string != text {
                textView.string = text
            }
        }
        textView.font = resolveNSFont(family: fontFamily, size: fontSize)
        textView.textColor = NSColor(textColor)
        textView.alignment = alignment

        // Update container width if changed
        if let container = textView.textContainer {
            container.containerSize = NSSize(width: maxWidth - 8, height: CGFloat.greatestFiniteMagnitude)
        }
        textView.maxSize = NSSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: maxWidth - 8, height: fontSize * 1.5)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSTextView, context: Context) -> CGSize? {
        let textView = nsView
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)

        if let container = textView.textContainer,
           let layoutManager = textView.layoutManager {
            let usedRect = layoutManager.usedRect(for: container)
            let height = max(fontSize * 1.5, usedRect.height + 8)
            return CGSize(width: maxWidth, height: height)
        }

        return CGSize(width: maxWidth, height: fontSize * 1.5)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ConstrainedAutoGrowingTextView
        /// Mirror of AutoGrowingTextView.Coordinator: set during textDidChange to block
        /// updateNSView from clobbering in-flight keystrokes.
        var isEditing = false

        init(_ parent: ConstrainedAutoGrowingTextView) {
            self.parent = parent
            super.init()
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }

            // Block updateNSView from overwriting the text we are about to publish
            isEditing = true
            parent.text = textView.string

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
                self?.isEditing = false
            }

            // Notify about height change
            if let container = textView.textContainer,
               let layoutManager = textView.layoutManager {
                layoutManager.ensureLayout(for: container)
                let usedRect = layoutManager.usedRect(for: container)
                let height = max(parent.fontSize * 1.5, usedRect.height + 8)
                parent.onHeightChange?(height)
            }
        }
    }
}
