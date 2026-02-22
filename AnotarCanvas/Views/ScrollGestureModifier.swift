//
//  ScrollGestureModifier.swift
//  AnotarCanvas
//
//  Created by Claude on 2026-02-18.
//

import SwiftUI
import AppKit

/// NSView that uses event monitors to capture scroll and magnify gestures globally
class ScrollCaptureNSView: NSView {
    var onScroll: ((CGPoint) -> Void)?
    var onMagnify: ((CGFloat, CGPoint) -> Void)?
    var onScrollZoom: ((CGFloat, CGPoint) -> Void)?

    private var scrollMonitor: Any?
    private var magnifyMonitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if window != nil {
            setupMonitors()
        } else {
            removeMonitors()
        }
    }

    private func setupMonitors() {
        // Monitor scroll wheel events
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self = self,
                  let window = self.window,
                  event.window == window else {
                return event
            }

            // Cmd+scroll or Ctrl+scroll = zoom
            if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control) {
                let zoomDelta = event.scrollingDeltaY * 0.01
                self.onScrollZoom?(zoomDelta, .zero)
                return event
            }

            let delta = CGPoint(
                x: event.scrollingDeltaX,
                y: event.scrollingDeltaY
            )
            self.onScroll?(delta)
            return event
        }

        // Monitor magnify (pinch) events
        magnifyMonitor = NSEvent.addLocalMonitorForEvents(matching: .magnify) { [weak self] event in
            guard let self = self,
                  let window = self.window,
                  event.window == window else {
                return event
            }

            self.onMagnify?(event.magnification, .zero)
            return event
        }
    }

    private func removeMonitors() {
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
        if let monitor = magnifyMonitor {
            NSEvent.removeMonitor(monitor)
            magnifyMonitor = nil
        }
    }

    deinit {
        removeMonitors()
    }
}

/// SwiftUI wrapper for scroll and magnification capture
struct ScrollCaptureView: NSViewRepresentable {
    let onScroll: (CGPoint) -> Void
    let onMagnify: ((CGFloat, CGPoint) -> Void)?
    let onScrollZoom: ((CGFloat, CGPoint) -> Void)?

    func makeNSView(context: Context) -> ScrollCaptureNSView {
        let view = ScrollCaptureNSView()
        view.onScroll = onScroll
        view.onMagnify = onMagnify
        view.onScrollZoom = onScrollZoom
        return view
    }

    func updateNSView(_ nsView: ScrollCaptureNSView, context: Context) {
        nsView.onScroll = onScroll
        nsView.onMagnify = onMagnify
        nsView.onScrollZoom = onScrollZoom
    }
}

/// View modifier to add scroll and magnification gesture handling
struct ScrollGestureModifier: ViewModifier {
    let onScroll: (CGPoint) -> Void
    let onMagnify: ((CGFloat, CGPoint) -> Void)?
    let onScrollZoom: ((CGFloat, CGPoint) -> Void)?

    func body(content: Content) -> some View {
        content
            .overlay(
                ScrollCaptureView(onScroll: onScroll, onMagnify: onMagnify, onScrollZoom: onScrollZoom)
                    .allowsHitTesting(false)
            )
    }
}

extension View {
    /// Add scroll and magnification gesture handlers for two-finger trackpad
    func onScrollGesture(
        scroll: @escaping (CGPoint) -> Void,
        magnify: ((CGFloat, CGPoint) -> Void)? = nil,
        scrollZoom: ((CGFloat, CGPoint) -> Void)? = nil
    ) -> some View {
        modifier(ScrollGestureModifier(onScroll: scroll, onMagnify: magnify, onScrollZoom: scrollZoom))
    }
}
