//
//  LineObjectView.swift
//  AnotarCanvas
//

import SwiftUI

struct LineObjectView: View {
    let object: LineObject
    let isSelected: Bool
    @ObservedObject var viewModel: CanvasViewModel

    private let arrowHeadLength: CGFloat = 14

    var body: some View {
        ZStack {
            // Line stroke (shortened if arrowheads are filled/circle/diamond)
            Path { path in
                let (adjustedStart, adjustedEnd) = adjustedLineEndpoints()
                path.move(to: adjustedStart)
                path.addLine(to: adjustedEnd)
            }
            .stroke(
                object.strokeColor,
                style: object.swiftUIStrokeStyle
            )

            // Start arrowhead
            if object.startArrowHead != .none {
                arrowHeadView(
                    at: object.startPoint,
                    angle: atan2(object.startPoint.y - object.endPoint.y,
                                 object.startPoint.x - object.endPoint.x),
                    style: object.startArrowHead
                )
            }

            // End arrowhead
            if object.endArrowHead != .none {
                arrowHeadView(
                    at: object.endPoint,
                    angle: atan2(object.endPoint.y - object.startPoint.y,
                                 object.endPoint.x - object.startPoint.x),
                    style: object.endArrowHead
                )
            }

            // Label at midpoint
            if !object.label.isEmpty {
                Text(object.label)
                    .font(object.labelAttributes.font)
                    .foregroundColor(object.labelAttributes.color)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.8))
                    .cornerRadius(3)
                    .position(object.midPoint)
            }

            // Selection indicators (control point handles)
            if isSelected {
                Circle()
                    .fill(Color.white)
                    .stroke(Color.accentColor, lineWidth: 1.5)
                    .frame(width: 8, height: 8)
                    .position(object.startPoint)

                Circle()
                    .fill(Color.white)
                    .stroke(Color.accentColor, lineWidth: 1.5)
                    .frame(width: 8, height: 8)
                    .position(object.endPoint)
            }
        }
    }

    /// Calculate adjusted line endpoints to prevent line from extending through filled arrowheads
    private func adjustedLineEndpoints() -> (CGPoint, CGPoint) {
        var adjustedStart = object.startPoint
        var adjustedEnd = object.endPoint

        // Calculate angle from start to end
        let angleToEnd = atan2(object.endPoint.y - object.startPoint.y,
                               object.endPoint.x - object.startPoint.x)

        // Shorten start point if start arrowhead is filled/circle/diamond
        if needsLineShortening(style: object.startArrowHead) {
            let shortenBy = arrowHeadShorteningDistance(style: object.startArrowHead)
            adjustedStart = CGPoint(
                x: object.startPoint.x + shortenBy * cos(angleToEnd),
                y: object.startPoint.y + shortenBy * sin(angleToEnd)
            )
        }

        // Shorten end point if end arrowhead is filled/circle/diamond
        if needsLineShortening(style: object.endArrowHead) {
            let shortenBy = arrowHeadShorteningDistance(style: object.endArrowHead)
            adjustedEnd = CGPoint(
                x: object.endPoint.x - shortenBy * cos(angleToEnd),
                y: object.endPoint.y - shortenBy * sin(angleToEnd)
            )
        }

        return (adjustedStart, adjustedEnd)
    }

    /// Check if arrowhead style requires line shortening
    private func needsLineShortening(style: ArrowHead) -> Bool {
        switch style {
        case .filled, .circle, .diamond:
            return true
        case .none, .open:
            return false
        }
    }

    /// Get the distance to shorten the line for different arrowhead styles
    private func arrowHeadShorteningDistance(style: ArrowHead) -> CGFloat {
        switch style {
        case .filled:
            // Shorten by the height of the filled triangle
            // Height = arrowHeadLength * cos(30°) ≈ arrowHeadLength * 0.866
            return arrowHeadLength * 0.866
        case .circle:
            // Shorten by the radius
            return arrowHeadLength / 2
        case .diamond:
            // Shorten by half the length so line stops at the center of the diamond
            // Diamond extends arrowHeadLength behind tip, so we shorten by half
            return arrowHeadLength / 2
        default:
            return 0
        }
    }

    @ViewBuilder
    private func arrowHeadView(at tip: CGPoint, angle: CGFloat, style: ArrowHead) -> some View {
        switch style {
        case .none:
            EmptyView()

        case .open:
            Path { path in
                path.move(to: CGPoint(
                    x: tip.x - arrowHeadLength * cos(angle - .pi / 6),
                    y: tip.y - arrowHeadLength * sin(angle - .pi / 6)
                ))
                path.addLine(to: tip)
                path.addLine(to: CGPoint(
                    x: tip.x - arrowHeadLength * cos(angle + .pi / 6),
                    y: tip.y - arrowHeadLength * sin(angle + .pi / 6)
                ))
            }
            .stroke(object.strokeColor, lineWidth: object.strokeWidth)

        case .filled:
            Path { path in
                path.move(to: tip)
                path.addLine(to: CGPoint(
                    x: tip.x - arrowHeadLength * cos(angle - .pi / 6),
                    y: tip.y - arrowHeadLength * sin(angle - .pi / 6)
                ))
                path.addLine(to: CGPoint(
                    x: tip.x - arrowHeadLength * cos(angle + .pi / 6),
                    y: tip.y - arrowHeadLength * sin(angle + .pi / 6)
                ))
                path.closeSubpath()
            }
            .fill(object.strokeColor)

        case .circle:
            // Center one radius behind the tip so the line doesn't poke through the circle
            let radius: CGFloat = arrowHeadLength / 2
            let cx = tip.x - radius * cos(angle)
            let cy = tip.y - radius * sin(angle)
            Circle()
                .fill(object.strokeColor)
                .frame(width: radius * 2, height: radius * 2)
                .position(x: cx, y: cy)

        case .diamond:
            // Diamond with tip at arrow point, center at half-length back, back point at full length
            let half = arrowHeadLength / 2
            let centerX = tip.x - half * cos(angle)
            let centerY = tip.y - half * sin(angle)
            Path { path in
                // Front tip (at the arrow point)
                path.move(to: tip)
                // Left side point (perpendicular at diamond center)
                path.addLine(to: CGPoint(
                    x: centerX - half * cos(angle - .pi / 2),
                    y: centerY - half * sin(angle - .pi / 2)
                ))
                // Back point (full arrowHeadLength behind tip)
                path.addLine(to: CGPoint(
                    x: tip.x - arrowHeadLength * cos(angle),
                    y: tip.y - arrowHeadLength * sin(angle)
                ))
                // Right side point (perpendicular at diamond center)
                path.addLine(to: CGPoint(
                    x: centerX - half * cos(angle + .pi / 2),
                    y: centerY - half * sin(angle + .pi / 2)
                ))
                path.closeSubpath()
            }
            .fill(object.strokeColor)
        }
    }
}
