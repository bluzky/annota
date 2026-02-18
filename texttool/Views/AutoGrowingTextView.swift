//
//  AutoGrowingTextView.swift
//  texttool
//
//  Created by Flex on 12/11/25.
//

import SwiftUI
import AppKit

struct AutoGrowingTextView: NSViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat
    var textColor: Color
    var onFocus: () -> Void
    var onSizeChange: ((CGSize) -> Void)?

    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()

        // Configure text view
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.font = NSFont.systemFont(ofSize: fontSize)
        textView.textColor = NSColor(textColor)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainerInset = NSSize(width: 4, height: 4)
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
        if textView.string != text {
            textView.string = text
        }
        textView.font = NSFont.systemFont(ofSize: fontSize)
        textView.textColor = NSColor(textColor)

        // Update min size based on font size
        textView.minSize = NSSize(width: 0, height: fontSize * 1.5)
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
            return CGSize(
                width: max(100, usedRect.width + 8),
                height: max(fontSize * 1.5, usedRect.height + 8)
            )
        }

        return CGSize(width: 100, height: fontSize * 1.5)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: AutoGrowingTextView

        init(_ parent: AutoGrowingTextView) {
            self.parent = parent
            super.init()
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string

            // Report size change
            if let container = textView.textContainer,
               let layoutManager = textView.layoutManager {
                layoutManager.ensureLayout(for: container)
                let usedRect = layoutManager.usedRect(for: container)
                let size = CGSize(
                    width: max(100, usedRect.width + 16),
                    height: max(parent.fontSize * 1.5, usedRect.height + 16)
                )
                parent.onSizeChange?(size)
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
        textView.font = NSFont.systemFont(ofSize: fontSize)
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
        if textView.string != text {
            textView.string = text
        }
        textView.font = NSFont.systemFont(ofSize: fontSize)
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

        init(_ parent: ConstrainedAutoGrowingTextView) {
            self.parent = parent
            super.init()
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string

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
