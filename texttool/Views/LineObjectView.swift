//
//  LineObjectView.swift
//  texttool
//

import SwiftUI

struct LineObjectView: View {
    let object: LineObject
    let isSelected: Bool
    @ObservedObject var viewModel: CanvasViewModel

    private let arrowHeadLength: CGFloat = 14

    var body: some View {
        ZStack {
            // Line stroke
            Path { path in
                path.move(to: object.startPoint)
                path.addLine(to: object.endPoint)
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
            let radius: CGFloat = arrowHeadLength / 2.5
            Circle()
                .fill(object.strokeColor)
                .frame(width: radius * 2, height: radius * 2)
                .position(tip)

        case .diamond:
            let half = arrowHeadLength / 2
            Path { path in
                path.move(to: CGPoint(x: tip.x + half * cos(angle), y: tip.y + half * sin(angle)))
                path.addLine(to: CGPoint(x: tip.x + half * cos(angle + .pi / 2), y: tip.y + half * sin(angle + .pi / 2)))
                path.addLine(to: CGPoint(x: tip.x - half * cos(angle), y: tip.y - half * sin(angle)))
                path.addLine(to: CGPoint(x: tip.x - half * cos(angle + .pi / 2), y: tip.y - half * sin(angle + .pi / 2)))
                path.closeSubpath()
            }
            .fill(object.strokeColor)
        }
    }
}
