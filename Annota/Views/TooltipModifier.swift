//
//  TooltipModifier.swift
//  Annota
//
//  Custom tooltip that appears after a short delay (~300ms) instead of the
//  native macOS ~1-2 second delay. Uses a lightweight NSWindow panel so it
//  won't be clipped by parent view bounds and looks clean (no popover arrow).
//

import SwiftUI
import AppKit

// MARK: - Tooltip Window

/// A borderless, transparent panel that hosts the tooltip label.
private final class TooltipWindow: NSPanel {
    static let shared = TooltipWindow()

    private let label: NSTextField = {
        let tf = NSTextField(labelWithString: "")
        tf.font = NSFont.systemFont(ofSize: 11)
        tf.textColor = .labelColor
        tf.backgroundColor = .clear
        tf.isBezeled = false
        tf.isEditable = false
        tf.isSelectable = false
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()

    private let bubble: NSVisualEffectView = {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.state = .active
        v.wantsLayer = true
        v.layer?.cornerRadius = 4
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        hidesOnDeactivate = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false

        let container = NSView()
        container.wantsLayer = true
        container.translatesAutoresizingMaskIntoConstraints = false
        contentView = container

        container.addSubview(bubble)
        bubble.addSubview(label)

        NSLayoutConstraint.activate([
            bubble.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bubble.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            bubble.topAnchor.constraint(equalTo: container.topAnchor),
            bubble.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            label.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -4),
        ])
    }

    func show(text: String, below rect: CGRect, in parentWindow: NSWindow) {
        label.stringValue = text
        label.sizeToFit()

        let padding = NSSize(width: 16, height: 8)
        let size = NSSize(
            width: label.fittingSize.width + padding.width,
            height: label.fittingSize.height + padding.height
        )

        // Position centered below the source view in screen coordinates
        let midX = rect.midX - size.width / 2
        let originY = rect.minY - size.height - 4
        let origin = NSPoint(x: midX, y: originY)

        setFrame(NSRect(origin: origin, size: size), display: true)
        parentWindow.addChildWindow(self, ordered: .above)
        alphaValue = 0
        orderFront(nil)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.1
            animator().alphaValue = 1
        }
    }

    func dismiss() {
        parent?.removeChildWindow(self)
        orderOut(nil)
        alphaValue = 0
    }
}

// MARK: - Tooltip Modifier

private struct TooltipModifier: ViewModifier {
    let text: String
    let delay: TimeInterval

    @State private var isHovering = false
    @State private var hoverTimer: Timer?
    @State private var viewFrame: CGRect = .zero

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(key: FramePreferenceKey.self, value: geo.frame(in: .global))
                }
            )
            .onPreferenceChange(FramePreferenceKey.self) { frame in
                viewFrame = frame
            }
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    hoverTimer?.invalidate()
                    hoverTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
                        DispatchQueue.main.async {
                            guard isHovering else { return }
                            guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }
                            let windowFrame = window.frame
                            let contentHeight = window.contentView?.frame.height ?? windowFrame.height
                            let screenRect = NSRect(
                                x: windowFrame.origin.x + viewFrame.origin.x,
                                y: windowFrame.origin.y + (contentHeight - viewFrame.maxY),
                                width: viewFrame.width,
                                height: viewFrame.height
                            )
                            TooltipWindow.shared.show(text: text, below: screenRect, in: window)
                        }
                    }
                } else {
                    hoverTimer?.invalidate()
                    hoverTimer = nil
                    TooltipWindow.shared.dismiss()
                }
            }
    }
}

private struct FramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

// MARK: - View Extension

extension View {
    /// Shows a custom tooltip after a short hover delay.
    /// Drop-in replacement for `.help()` with faster appearance.
    func tooltip(_ text: String, delay: TimeInterval = 0.3) -> some View {
        modifier(TooltipModifier(text: text, delay: delay))
    }
}
