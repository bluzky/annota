//
//  ViewportState.swift
//  texttool
//
//  Created by Claude on 2026-02-18.
//

import SwiftUI

/// Manages canvas viewport state for pan and zoom
struct ViewportState: Equatable {
    /// Pan offset (translation of the canvas)
    var offset: CGPoint = .zero

    /// Zoom scale (1.0 = 100%)
    var scale: CGFloat = 1.0

    // MARK: - Zoom Limits

    static let minScale: CGFloat = 0.1
    static let maxScale: CGFloat = 5.0
    static let defaultScale: CGFloat = 1.0

    // MARK: - Computed Properties

    /// Zoom percentage for display (e.g., 100 for scale 1.0)
    var zoomPercentage: Int {
        Int(round(scale * 100))
    }

    // MARK: - Coordinate Transformations

    /// Convert screen point to canvas point
    func screenToCanvas(_ screenPoint: CGPoint) -> CGPoint {
        CGPoint(
            x: (screenPoint.x - offset.x) / scale,
            y: (screenPoint.y - offset.y) / scale
        )
    }

    /// Convert canvas point to screen point
    func canvasToScreen(_ canvasPoint: CGPoint) -> CGPoint {
        CGPoint(
            x: canvasPoint.x * scale + offset.x,
            y: canvasPoint.y * scale + offset.y
        )
    }

    /// Convert screen size to canvas size
    func screenToCanvasSize(_ screenSize: CGSize) -> CGSize {
        CGSize(
            width: screenSize.width / scale,
            height: screenSize.height / scale
        )
    }

    // MARK: - Mutations

    /// Apply pan offset
    mutating func pan(by delta: CGSize) {
        offset.x += delta.width
        offset.y += delta.height
    }

    /// Zoom by a factor around a specific point (for pinch-to-zoom)
    mutating func zoom(by factor: CGFloat, around anchor: CGPoint) {
        let newScale = clampScale(scale * factor)
        let actualFactor = newScale / scale

        // Adjust offset to keep anchor point stationary
        offset.x = anchor.x - (anchor.x - offset.x) * actualFactor
        offset.y = anchor.y - (anchor.y - offset.y) * actualFactor

        scale = newScale
    }

    /// Set zoom level around center
    mutating func setScale(_ newScale: CGFloat, around anchor: CGPoint) {
        let clampedScale = clampScale(newScale)
        let factor = clampedScale / scale

        offset.x = anchor.x - (anchor.x - offset.x) * factor
        offset.y = anchor.y - (anchor.y - offset.y) * factor

        scale = clampedScale
    }

    /// Reset to default state
    mutating func reset() {
        offset = .zero
        scale = Self.defaultScale
    }

    /// Clamp scale to valid range
    private func clampScale(_ value: CGFloat) -> CGFloat {
        min(max(value, Self.minScale), Self.maxScale)
    }
}
