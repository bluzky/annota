//
//  RotationMathTests.swift
//  texttoolTests
//
//  Unit tests for rotation math: coordinate transforms, angle calculation,
//  15-degree snapping, and group orbit math.
//

import Testing
import SwiftUI
import CoreGraphics
import Foundation
@testable import texttool

@MainActor
struct RotationMathTests {

    // MARK: - Helpers

    /// Tolerance for floating-point comparisons
    private let epsilon: CGFloat = 1e-10

    private func assertPointsEqual(_ a: CGPoint, _ b: CGPoint, tolerance: CGFloat = 1e-10, sourceLocation: Testing.SourceLocation = #_sourceLocation) {
        #expect(abs(a.x - b.x) < tolerance, sourceLocation: sourceLocation)
        #expect(abs(a.y - b.y) < tolerance, sourceLocation: sourceLocation)
    }

    // MARK: - CanvasObject.transformToLocal (inverse rotation)

    @Test func transformToLocalIdentityAtZeroRotation() async throws {
        var rect = RectangleObject(
            position: CGPoint(x: 100, y: 100),
            size: CGSize(width: 200, height: 100),
            color: .blue
        )
        rect.rotation = 0

        let point = CGPoint(x: 150, y: 175)
        let local = rect.transformToLocal(point)

        // Zero rotation: point unchanged
        assertPointsEqual(local, point)
    }

    @Test func transformToLocalQuarterTurnRotatesAroundCenter() async throws {
        // Object centered at (200, 150)
        var rect = RectangleObject(
            position: CGPoint(x: 100, y: 100),
            size: CGSize(width: 200, height: 100),
            color: .blue
        )
        rect.rotation = .pi / 2  // 90°

        // A point at the right edge of the object (center + (100, 0) in canvas space)
        let canvasPoint = CGPoint(x: 300, y: 150)  // center.x + 100
        let local = rect.transformToLocal(canvasPoint)

        // Rotating by -90° around center (200, 150):
        // dx = 300 - 200 = 100, dy = 150 - 150 = 0
        // x' = cx + dx*cos(-90) - dy*sin(-90) = 200 + 100*0 - 0*(-1) = 200
        // y' = cy + dx*sin(-90) + dy*cos(-90) = 150 + 100*(-1) + 0*0 = 50
        assertPointsEqual(local, CGPoint(x: 200, y: 50))
    }

    @Test func transformToLocalHalfTurnReflectsAroundCenter() async throws {
        var rect = RectangleObject(
            position: CGPoint(x: 0, y: 0),
            size: CGSize(width: 100, height: 100),
            color: .blue
        )
        rect.rotation = .pi  // 180°

        // Center is at (50, 50)
        // Point at top-left corner: (0, 0)
        let local = rect.transformToLocal(CGPoint(x: 0, y: 0))

        // -180° rotation around (50, 50):
        // dx = 0 - 50 = -50, dy = 0 - 50 = -50
        // cos(-pi) = -1, sin(-pi) ≈ 0
        // x' = 50 + (-50)*(-1) - (-50)*0 = 50 + 50 = 100
        // y' = 50 + (-50)*0 + (-50)*(-1) = 50 + 50 = 100
        assertPointsEqual(local, CGPoint(x: 100, y: 100), tolerance: 1e-5)
    }

    @Test func transformToCanvasIsInverseOfTransformToLocal() async throws {
        var rect = RectangleObject(
            position: CGPoint(x: 50, y: 75),
            size: CGSize(width: 150, height: 80),
            color: .blue
        )
        rect.rotation = CGFloat.pi / 6  // 30°

        let original = CGPoint(x: 200, y: 100)
        let local = rect.transformToLocal(original)
        let back = rect.transformToCanvas(local)

        assertPointsEqual(back, original, tolerance: 1e-10)
    }

    @Test func transformToCanvasAndLocalRoundTripVariousAngles() async throws {
        let angles: [CGFloat] = [.pi / 6, .pi / 4, .pi / 3, .pi / 2, .pi, 3 * .pi / 2]
        let point = CGPoint(x: 300, y: 200)

        for angle in angles {
            var rect = RectangleObject(
                position: CGPoint(x: 100, y: 100),
                size: CGSize(width: 200, height: 100),
                color: .blue
            )
            rect.rotation = angle

            let local = rect.transformToLocal(point)
            let back = rect.transformToCanvas(local)
            assertPointsEqual(back, point, tolerance: 1e-10)
        }
    }

    @Test func transformToCanvasForwardRotationQuarterTurn() async throws {
        // Object centered at (200, 150)
        var rect = RectangleObject(
            position: CGPoint(x: 100, y: 100),
            size: CGSize(width: 200, height: 100),
            color: .blue
        )
        rect.rotation = .pi / 2  // 90°

        // Point at object-local top edge: center + (0, -50) in local space
        // In canvas, that's center + rotated(0, -50) by 90°
        let localPoint = CGPoint(x: 200, y: 100)  // center.x, center.y - 50
        let canvas = rect.transformToCanvas(localPoint)

        // dx = 200 - 200 = 0, dy = 100 - 150 = -50
        // cos(90°) = 0, sin(90°) = 1
        // x' = 200 + 0*0 - (-50)*1 = 200 + 50 = 250
        // y' = 150 + 0*1 + (-50)*0 = 150
        assertPointsEqual(canvas, CGPoint(x: 250, y: 150), tolerance: 1e-10)
    }

    // MARK: - rotatePoint (generic helper) math tests

    /// Replicates the rotatePoint function used in CanvasView
    private func rotatePoint(_ point: CGPoint, around center: CGPoint, by angle: CGFloat) -> CGPoint {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let cosA = cos(angle)
        let sinA = sin(angle)
        return CGPoint(
            x: center.x + dx * cosA - dy * sinA,
            y: center.y + dx * sinA + dy * cosA
        )
    }

    @Test func rotatePointByZeroIsIdentity() async throws {
        let center = CGPoint(x: 100, y: 100)
        let point = CGPoint(x: 200, y: 150)
        let result = rotatePoint(point, around: center, by: 0)
        assertPointsEqual(result, point)
    }

    @Test func rotatePointBy90Degrees() async throws {
        let center = CGPoint(x: 0, y: 0)
        let point = CGPoint(x: 1, y: 0)
        let result = rotatePoint(point, around: center, by: .pi / 2)
        // (1,0) rotated 90° CCW → (0, 1)
        assertPointsEqual(result, CGPoint(x: 0, y: 1), tolerance: 1e-10)
    }

    @Test func rotatePointBy180Degrees() async throws {
        let center = CGPoint(x: 0, y: 0)
        let point = CGPoint(x: 3, y: 4)
        let result = rotatePoint(point, around: center, by: .pi)
        // 180° rotation negates both coordinates
        assertPointsEqual(result, CGPoint(x: -3, y: -4), tolerance: 1e-10)
    }

    @Test func rotatePointAroundNonOriginCenter() async throws {
        let center = CGPoint(x: 50, y: 50)
        // Point directly to the right of center
        let point = CGPoint(x: 100, y: 50)
        let result = rotatePoint(point, around: center, by: .pi / 2)
        // 90° CCW: relative (50, 0) → (0, 50), so result = (50, 100)
        assertPointsEqual(result, CGPoint(x: 50, y: 100), tolerance: 1e-10)
    }

    @Test func rotatePointFullCircleReturnsToOrigin() async throws {
        let center = CGPoint(x: 200, y: 150)
        let point = CGPoint(x: 300, y: 200)
        let result = rotatePoint(point, around: center, by: 2 * .pi)
        assertPointsEqual(result, point, tolerance: 1e-10)
    }

    @Test func rotatePointForwardThenInverseRoundTrip() async throws {
        let center = CGPoint(x: 150, y: 100)
        let point = CGPoint(x: 250, y: 175)
        let angle = CGFloat.pi / 7

        let rotated = rotatePoint(point, around: center, by: angle)
        let back = rotatePoint(rotated, around: center, by: -angle)
        assertPointsEqual(back, point, tolerance: 1e-10)
    }

    // MARK: - 15-degree snap angle math

    private func snapTo15Degrees(_ angle: CGFloat) -> CGFloat {
        let snapAngle = CGFloat.pi / 12  // 15°
        return (angle / snapAngle).rounded() * snapAngle
    }

    @Test func snapAngleUnder7point5DegreesSnapsToZero() async throws {
        let angle = CGFloat(5) * .pi / 180  // 5° → snaps to 0°
        let snapped = snapTo15Degrees(angle)
        #expect(abs(snapped) < 1e-10)
    }

    @Test func snapAngleOver7point5DegreesSnapsTo15() async throws {
        let angle = CGFloat(10) * .pi / 180  // 10° → snaps to 15°
        let snapped = snapTo15Degrees(angle)
        #expect(abs(snapped - CGFloat.pi / 12) < 1e-10)
    }

    @Test func snapAngle30DegreesExact() async throws {
        let angle = CGFloat(30) * .pi / 180  // 30° → stays 30°
        let snapped = snapTo15Degrees(angle)
        #expect(abs(snapped - CGFloat.pi / 6) < 1e-10)
    }

    @Test func snapAngle45DegreesExact() async throws {
        let angle = CGFloat(45) * .pi / 180  // 45° exact
        let snapped = snapTo15Degrees(angle)
        #expect(abs(snapped - CGFloat.pi / 4) < 1e-10)
    }

    @Test func snapAngleNegativeSnapsToNegative15() async throws {
        let angle = CGFloat(-10) * .pi / 180  // -10° → snaps to -15°
        let snapped = snapTo15Degrees(angle)
        #expect(abs(snapped - (-CGFloat.pi / 12)) < 1e-10)
    }

    // MARK: - Group rotation: orbit math

    /// Simulates the group rotation orbit calculation from CanvasView
    private func orbitCenter(_ objectCenter: CGPoint, aroundGroupCenter groupCenter: CGPoint, by angleDelta: CGFloat) -> CGPoint {
        return rotatePoint(objectCenter, around: groupCenter, by: angleDelta)
    }

    @Test func orbitCenterAroundSelfIsNoOp() async throws {
        let center = CGPoint(x: 100, y: 100)
        let result = orbitCenter(center, aroundGroupCenter: center, by: .pi / 4)
        assertPointsEqual(result, center, tolerance: 1e-10)
    }

    @Test func orbitCenterBy90DegreesCorrectPosition() async throws {
        let groupCenter = CGPoint(x: 200, y: 200)
        let objectCenter = CGPoint(x: 300, y: 200)  // Right of group center

        let newCenter = orbitCenter(objectCenter, aroundGroupCenter: groupCenter, by: .pi / 2)

        // Relative (100, 0) rotated 90° CCW → (0, 100), so result = (200, 300)
        assertPointsEqual(newCenter, CGPoint(x: 200, y: 300), tolerance: 1e-10)
    }

    @Test func orbitCenterFullCircleReturnsToStart() async throws {
        let groupCenter = CGPoint(x: 0, y: 0)
        let objectCenter = CGPoint(x: 150, y: 75)

        let after = orbitCenter(objectCenter, aroundGroupCenter: groupCenter, by: 2 * .pi)
        assertPointsEqual(after, objectCenter, tolerance: 1e-10)
    }

    @Test func orbitCenterMultipleObjectsMaintainRelativePositions() async throws {
        let groupCenter = CGPoint(x: 200, y: 200)
        let obj1 = CGPoint(x: 300, y: 200)  // right
        let obj2 = CGPoint(x: 100, y: 200)  // left

        let angle = CGFloat.pi / 2  // 90°

        let new1 = orbitCenter(obj1, aroundGroupCenter: groupCenter, by: angle)
        let new2 = orbitCenter(obj2, aroundGroupCenter: groupCenter, by: angle)

        // obj1: (100, 0) → (0, 100) → (200, 300)
        // obj2: (-100, 0) → (0, -100) → (200, 100)
        assertPointsEqual(new1, CGPoint(x: 200, y: 300), tolerance: 1e-10)
        assertPointsEqual(new2, CGPoint(x: 200, y: 100), tolerance: 1e-10)

        // Relative distance between objects should be preserved
        let origDist = hypot(obj1.x - obj2.x, obj1.y - obj2.y)
        let newDist = hypot(new1.x - new2.x, new1.y - new2.y)
        #expect(abs(origDist - newDist) < 1e-10)
    }

    // MARK: - SelectionBox rotated corner computation

    @Test func rotatedCornersOfAxisAlignedRectAtZeroAreOriginalCorners() async throws {
        // A non-rotated object's selection box corners from multi-select
        let rect1 = RectangleObject(
            position: CGPoint(x: 0, y: 0),
            size: CGSize(width: 100, height: 100),
            color: .blue,
            rotation: 0
        )
        let rect2 = RectangleObject(
            position: CGPoint(x: 200, y: 0),
            size: CGSize(width: 100, height: 100),
            color: .red,
            rotation: 0
        )
        let box = SelectionBox.from(objects: [AnyCanvasObject(rect1), AnyCanvasObject(rect2)])!

        // With no rotation, AABB should just span from 0,0 to 300,100
        #expect(box.bounds.minX == 0)
        #expect(box.bounds.minY == 0)
        #expect(abs(box.bounds.maxX - 300) < 1e-5)
        #expect(abs(box.bounds.maxY - 100) < 1e-5)
    }

    @Test func rotatedCornersOfSquareAt45DegreesExpandAABB() async throws {
        // A square at 45° rotation should have larger AABB than original square
        // Square: 100x100 centered at (150, 150)
        let rect = RectangleObject(
            position: CGPoint(x: 100, y: 100),
            size: CGSize(width: 100, height: 100),
            color: .blue,
            rotation: .pi / 4  // 45°
        )
        // Second object at far corner to force multi-select path
        let anchor = RectangleObject(
            position: CGPoint(x: 500, y: 500),
            size: CGSize(width: 1, height: 1),
            color: .red
        )
        let box = SelectionBox.from(objects: [AnyCanvasObject(rect), AnyCanvasObject(anchor)])!

        // For a 100x100 square rotated 45°, the AABB extent from center is:
        // half-diagonal = 100*sqrt(2)/2 ≈ 70.71
        // So minX ≈ 150 - 70.71 ≈ 79.29 (less than the original 100)
        // The AABB width ≈ 2 * 70.71 ≈ 141.4 (greater than original 100)
        let expectedHalfDiag = 100.0 * sqrt(2.0) / 2.0
        let rectAABBWidth = expectedHalfDiag * 2

        // The actual box encompasses both rects, but the rotated rect's AABB should be ~141
        // and the bounding box minimum from rect should be around center - half-diag
        let rotatedMinX = 150.0 - expectedHalfDiag
        #expect(box.bounds.minX <= rotatedMinX + 1e-5)
        #expect(box.bounds.width > rectAABBWidth - 1)  // At least as wide as rotated rect
    }

    // MARK: - atan2 angle calculation (rotation handle math)

    @Test func atan2AngleFromCenterToRight() async throws {
        let center = CGPoint(x: 200, y: 200)
        let point = CGPoint(x: 300, y: 200)  // Directly right

        let angle = atan2(point.y - center.y, point.x - center.x)
        #expect(abs(angle) < 1e-10)  // 0°
    }

    @Test func atan2AngleFromCenterToBottom() async throws {
        let center = CGPoint(x: 200, y: 200)
        let point = CGPoint(x: 200, y: 300)  // Directly down (SwiftUI y-down)

        let angle = atan2(point.y - center.y, point.x - center.x)
        #expect(abs(angle - .pi / 2) < 1e-10)  // 90° (positive y = down in SwiftUI)
    }

    @Test func angleDeltaCalculationForRotation() async throws {
        let rotationCenter = CGPoint(x: 200, y: 200)

        let startPoint = CGPoint(x: 300, y: 200)  // angle = 0
        let endPoint = CGPoint(x: 200, y: 300)    // angle = 90°

        let startAngle = atan2(startPoint.y - rotationCenter.y, startPoint.x - rotationCenter.x)
        let endAngle = atan2(endPoint.y - rotationCenter.y, endPoint.x - rotationCenter.x)
        let delta = endAngle - startAngle

        #expect(abs(delta - .pi / 2) < 1e-10)
    }
}
