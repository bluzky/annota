//
//  InfiniteGridView.swift
//  AnotarCanvas
//
//  Created by Claude on 2026-02-18.
//

import SwiftUI

/// Renders an infinite dot grid that moves with the viewport
struct InfiniteGridView: View {
    let viewport: ViewportState

    private let dotSpacing: CGFloat = 20
    private let dotRadius: CGFloat = 1
    private let dotColor = Color(red: 0xc0/255, green: 0xc0/255, blue: 0xc0/255)

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // Calculate the effective dot spacing based on zoom
                let effectiveSpacing = dotSpacing * viewport.scale

                // Skip drawing if dots would be too small or too dense
                guard effectiveSpacing >= 5 else { return }

                // Calculate offset to align grid with canvas coordinates
                let offsetX = viewport.offset.x.truncatingRemainder(dividingBy: effectiveSpacing)
                let offsetY = viewport.offset.y.truncatingRemainder(dividingBy: effectiveSpacing)

                // Draw dots across the visible area
                let startX = offsetX - effectiveSpacing
                let startY = offsetY - effectiveSpacing
                let endX = size.width + effectiveSpacing
                let endY = size.height + effectiveSpacing

                let effectiveRadius = dotRadius * min(viewport.scale, 1.5)

                for x in stride(from: startX, through: endX, by: effectiveSpacing) {
                    for y in stride(from: startY, through: endY, by: effectiveSpacing) {
                        let rect = CGRect(
                            x: x - effectiveRadius,
                            y: y - effectiveRadius,
                            width: effectiveRadius * 2,
                            height: effectiveRadius * 2
                        )
                        context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                    }
                }
            }
            .background(Color.white)
        }
    }
}
