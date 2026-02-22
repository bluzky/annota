//
//  MarqueeView.swift
//  texttool
//
//  Created by Claude on 2/18/26.
//

import SwiftUI

/// Visual feedback view for marquee (drag-to-select) rectangle
struct MarqueeView: View {
    let startPoint: CGPoint
    let currentPoint: CGPoint

    var body: some View {
        let rect = normalizedRect
        Rectangle()
            .fill(Color.blue.opacity(0.1))
            .overlay(
                Rectangle()
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 1, dash: [4, 2])
                    )
                    .foregroundColor(.blue)
            )
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }

    /// Compute normalized rectangle from start and current points
    private var normalizedRect: CGRect {
        let x = min(startPoint.x, currentPoint.x)
        let y = min(startPoint.y, currentPoint.y)
        let width = abs(currentPoint.x - startPoint.x)
        let height = abs(currentPoint.y - startPoint.y)
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
