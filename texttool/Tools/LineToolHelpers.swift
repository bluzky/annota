//
//  LineToolHelpers.swift
//  texttool
//
//  Shared geometry helpers for line and arrow tool plugins.
//

import CoreGraphics

/// Constrains an endpoint to the nearest 15-degree angle from the start point.
/// Used by both LineToolPlugin and ArrowToolPlugin for shift+drag snapping.
func constrainLineToAngle(from start: CGPoint, to end: CGPoint) -> CGPoint {
    let dx = end.x - start.x
    let dy = end.y - start.y
    let distance = hypot(dx, dy)
    let angle = atan2(dy, dx)
    let snapAngle = CGFloat.pi / 12
    let snappedAngle = (angle / snapAngle).rounded() * snapAngle
    return CGPoint(
        x: start.x + distance * cos(snappedAngle),
        y: start.y + distance * sin(snappedAngle)
    )
}
