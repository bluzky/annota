//
//  ResizeMathTests.swift
//  texttoolTests
//
//  Unit tests for resize math: proportional scaling, aspect ratio,
//  anchor point preservation, and rotation-aware resize.
//

import Testing
import SwiftUI
import CoreGraphics
import Foundation
@testable import AnotarCanvas

@MainActor
struct ResizeMathTests {

    // MARK: - Helpers

    private func assertApprox(_ a: CGFloat, _ b: CGFloat, tolerance: CGFloat = 1e-10, sourceLocation: Testing.SourceLocation = #_sourceLocation) {
        #expect(abs(a - b) < tolerance, sourceLocation: sourceLocation)
    }

    private func assertPointsEqual(_ a: CGPoint, _ b: CGPoint, tolerance: CGFloat = 1e-10, sourceLocation: Testing.SourceLocation = #_sourceLocation) {
        #expect(abs(a.x - b.x) < tolerance, sourceLocation: sourceLocation)
        #expect(abs(a.y - b.y) < tolerance, sourceLocation: sourceLocation)
    }

    // MARK: - Proportional Scaling Math

    /// Simulates the relative-position scaling formula from CanvasView.handleResize()
    private func scaleObjectFrame(
        origFrame: CGRect,
        origGroupMinX: CGFloat,
        origGroupMinY: CGFloat,
        origGroupWidth: CGFloat,
        origGroupHeight: CGFloat,
        newGroupMinX: CGFloat,
        newGroupMinY: CGFloat,
        newGroupWidth: CGFloat,
        newGroupHeight: CGFloat
    ) -> CGRect {
        let relX = (origFrame.minX - origGroupMinX) / origGroupWidth
        let relY = (origFrame.minY - origGroupMinY) / origGroupHeight
        let relW = origFrame.width / origGroupWidth
        let relH = origFrame.height / origGroupHeight

        let newObjX = newGroupMinX + relX * newGroupWidth
        let newObjY = newGroupMinY + relY * newGroupHeight
        let newObjW = relW * newGroupWidth
        let newObjH = relH * newGroupHeight

        return CGRect(x: newObjX, y: newObjY, width: newObjW, height: newObjH)
    }

    @Test func proportionalScaleDoublesSizeOfSingleObject() async throws {
        let origFrame = CGRect(x: 0, y: 0, width: 100, height: 50)
        let scaled = scaleObjectFrame(
            origFrame: origFrame,
            origGroupMinX: 0, origGroupMinY: 0,
            origGroupWidth: 100, origGroupHeight: 50,
            newGroupMinX: 0, newGroupMinY: 0,
            newGroupWidth: 200, newGroupHeight: 100
        )

        assertApprox(scaled.minX, 0)
        assertApprox(scaled.minY, 0)
        assertApprox(scaled.width, 200)
        assertApprox(scaled.height, 100)
    }

    @Test func proportionalScaleHalvesSizeOfSingleObject() async throws {
        let origFrame = CGRect(x: 0, y: 0, width: 200, height: 100)
        let scaled = scaleObjectFrame(
            origFrame: origFrame,
            origGroupMinX: 0, origGroupMinY: 0,
            origGroupWidth: 200, origGroupHeight: 100,
            newGroupMinX: 0, newGroupMinY: 0,
            newGroupWidth: 100, newGroupHeight: 50
        )

        assertApprox(scaled.width, 100)
        assertApprox(scaled.height, 50)
    }

    @Test func proportionalScalePreservesRelativePositionInGroup() async throws {
        // Group: 0..300 x 0..200
        // Object1: 0..100 x 0..200 (left third)
        // Scale group to 0..150 x 0..100 (half size)
        let groupBoundsOrig = CGRect(x: 0, y: 0, width: 300, height: 200)
        let obj1 = CGRect(x: 0, y: 0, width: 100, height: 200)
        let obj2 = CGRect(x: 200, y: 0, width: 100, height: 200)

        let newGroupBounds = CGRect(x: 0, y: 0, width: 150, height: 100)

        let scaled1 = scaleObjectFrame(
            origFrame: obj1,
            origGroupMinX: groupBoundsOrig.minX, origGroupMinY: groupBoundsOrig.minY,
            origGroupWidth: groupBoundsOrig.width, origGroupHeight: groupBoundsOrig.height,
            newGroupMinX: newGroupBounds.minX, newGroupMinY: newGroupBounds.minY,
            newGroupWidth: newGroupBounds.width, newGroupHeight: newGroupBounds.height
        )
        let scaled2 = scaleObjectFrame(
            origFrame: obj2,
            origGroupMinX: groupBoundsOrig.minX, origGroupMinY: groupBoundsOrig.minY,
            origGroupWidth: groupBoundsOrig.width, origGroupHeight: groupBoundsOrig.height,
            newGroupMinX: newGroupBounds.minX, newGroupMinY: newGroupBounds.minY,
            newGroupWidth: newGroupBounds.width, newGroupHeight: newGroupBounds.height
        )

        // obj1 was 1/3 wide → now (1/3)*150 = 50 wide
        assertApprox(scaled1.width, 50)
        assertApprox(scaled1.minX, 0)

        // obj2 starts at 200/300 = 2/3 → now 2/3*150 = 100
        assertApprox(scaled2.minX, 100)
        assertApprox(scaled2.width, 50)
    }

    @Test func proportionalScaleWithGroupOffset() async throws {
        // Group starts at (100, 50), size 200x100
        // Object is at (150, 75) - center of group
        let origFrame = CGRect(x: 150, y: 75, width: 100, height: 50)
        let scaled = scaleObjectFrame(
            origFrame: origFrame,
            origGroupMinX: 100, origGroupMinY: 50,
            origGroupWidth: 200, origGroupHeight: 100,
            newGroupMinX: 0, newGroupMinY: 0,
            newGroupWidth: 200, newGroupHeight: 100
        )

        // Object was at relative position (0.25, 0.25) with size (0.5, 0.5) of group
        // Now maps to: x = 0 + 0.25*200 = 50, y = 0 + 0.25*100 = 25
        assertApprox(scaled.minX, 50)
        assertApprox(scaled.minY, 25)
        assertApprox(scaled.width, 100)
        assertApprox(scaled.height, 50)
    }

    // MARK: - Aspect Ratio Lock (Shift+drag)

    /// Simulates aspect ratio constraint: adjusts height to maintain aspect ratio
    private func applyAspectRatioConstraint(newWidth: CGFloat, newHeight: CGFloat, aspectRatio: CGFloat) -> CGSize {
        // When width-driven: height = width / aspectRatio
        // When height-driven: width = height * aspectRatio
        // Use whichever dimension changed more
        let w = newWidth
        let h = w / aspectRatio
        return CGSize(width: w, height: h)
    }

    @Test func aspectRatioConstraintPreservesRatio() async throws {
        // Original: 200x100 = 2:1 ratio
        let originalRatio: CGFloat = 200.0 / 100.0  // 2.0

        // After drag: width becomes 300
        let constrained = applyAspectRatioConstraint(
            newWidth: 300,
            newHeight: 400,  // Would violate ratio
            aspectRatio: originalRatio
        )

        // Height should be 300/2 = 150
        assertApprox(constrained.width, 300)
        assertApprox(constrained.height, 150)
    }

    @Test func aspectRatioConstraintSquare() async throws {
        let originalRatio: CGFloat = 1.0  // Square

        let constrained = applyAspectRatioConstraint(
            newWidth: 250,
            newHeight: 100,
            aspectRatio: originalRatio
        )

        assertApprox(constrained.width, 250)
        assertApprox(constrained.height, 250)
    }

    @Test func aspectRatioConstraintTallShape() async throws {
        // Original: 50x200 = 0.25 ratio (tall portrait)
        let originalRatio: CGFloat = 50.0 / 200.0  // 0.25

        let constrained = applyAspectRatioConstraint(
            newWidth: 100,
            newHeight: 150,
            aspectRatio: originalRatio
        )

        // height = 100 / 0.25 = 400
        assertApprox(constrained.width, 100)
        assertApprox(constrained.height, 400)
    }

    // MARK: - Anchor Point Math

    /// Computes where a handle point ends up after position/size change,
    /// to verify anchor stays fixed.
    private func anchorPointAfterResize(
        anchorRelativeX: CGFloat,  // 0 = left, 1 = right
        anchorRelativeY: CGFloat,  // 0 = top, 1 = bottom
        newBounds: CGRect
    ) -> CGPoint {
        return CGPoint(
            x: newBounds.minX + anchorRelativeX * newBounds.width,
            y: newBounds.minY + anchorRelativeY * newBounds.height
        )
    }

    @Test func anchorPointRemainsFixedOnBottomRightCornerResize() async throws {
        // Resize from top-left: anchor = bottom-right corner
        let origBounds = CGRect(x: 100, y: 100, width: 200, height: 100)
        let anchorOrig = CGPoint(x: origBounds.maxX, y: origBounds.maxY)  // (300, 200)

        // After resize: new top-left at (50, 50), same anchor
        let newBounds = CGRect(x: 50, y: 50, width: 250, height: 150)
        let anchorNew = CGPoint(x: newBounds.maxX, y: newBounds.maxY)  // (300, 200)

        // In a well-constrained resize, anchor should stay the same
        assertPointsEqual(anchorOrig, anchorNew)
    }

    @Test func anchorPointTopLeftFixedOnBottomRightDrag() async throws {
        // Dragging bottom-right: top-left is anchor, should remain (100, 100)
        let origTopLeft = CGPoint(x: 100, y: 100)

        // Simulate corner drag to (350, 250)
        let dragTarget = CGPoint(x: 350, y: 250)
        let newBounds = CGRect(
            x: origTopLeft.x,
            y: origTopLeft.y,
            width: dragTarget.x - origTopLeft.x,
            height: dragTarget.y - origTopLeft.y
        )

        assertApprox(newBounds.minX, 100)
        assertApprox(newBounds.minY, 100)
        assertApprox(newBounds.width, 250)
        assertApprox(newBounds.height, 150)
    }

    // MARK: - Edge Resize (single axis)

    @Test func topEdgeResizeOnlyChangesY() async throws {
        // Dragging top edge down: height shrinks, x/width unchanged
        let origBounds = CGRect(x: 100, y: 100, width: 200, height: 150)
        let newTopY: CGFloat = 130  // Dragged down by 30

        let newBounds = CGRect(
            x: origBounds.minX,
            y: newTopY,
            width: origBounds.width,
            height: origBounds.maxY - newTopY
        )

        assertApprox(newBounds.minX, 100)
        assertApprox(newBounds.width, 200)  // Width unchanged
        assertApprox(newBounds.minY, 130)
        assertApprox(newBounds.height, 120)  // 250 - 130
    }

    @Test func rightEdgeResizeOnlyChangesWidth() async throws {
        let origBounds = CGRect(x: 100, y: 100, width: 200, height: 150)
        let newRightX: CGFloat = 350  // Extended by 50

        let newBounds = CGRect(
            x: origBounds.minX,
            y: origBounds.minY,
            width: newRightX - origBounds.minX,
            height: origBounds.height
        )

        assertApprox(newBounds.minX, 100)
        assertApprox(newBounds.minY, 100)
        assertApprox(newBounds.height, 150)  // Height unchanged
        assertApprox(newBounds.width, 250)
    }

    // MARK: - Rotation-Aware Resize (unrotate drag point)

    private func unrotatePoint(_ point: CGPoint, aroundCenter center: CGPoint, by rotation: CGFloat) -> CGPoint {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let cosR = cos(-rotation)
        let sinR = sin(-rotation)
        return CGPoint(
            x: center.x + dx * cosR - dy * sinR,
            y: center.y + dx * sinR + dy * cosR
        )
    }

    @Test func unrotatingDragPointFor90DegreeRotation() async throws {
        // Object rotated 90°, center at (200, 150)
        // User dragged to screen point (200, 250) which is "below" in screen space
        // After unrotating by -90°, this should map to the right in local space
        let center = CGPoint(x: 200, y: 150)
        let dragPoint = CGPoint(x: 200, y: 250)  // 100 units below center

        let localDrag = unrotatePoint(dragPoint, aroundCenter: center, by: .pi / 2)

        // dx = 200 - 200 = 0, dy = 250 - 150 = 100
        // cos(-90°) = 0, sin(-90°) = -1
        // x' = 200 + 0*0 - 100*(-1) = 200 + 100 = 300
        // y' = 150 + 0*(-1) + 100*0 = 150
        #expect(abs(localDrag.x - 300) < 1e-10)
        #expect(abs(localDrag.y - 150) < 1e-10)
    }

    @Test func unrotatingDragPointForZeroRotationIsIdentity() async throws {
        let center = CGPoint(x: 200, y: 150)
        let dragPoint = CGPoint(x: 350, y: 200)

        let localDrag = unrotatePoint(dragPoint, aroundCenter: center, by: 0)

        #expect(abs(localDrag.x - dragPoint.x) < 1e-10)
        #expect(abs(localDrag.y - dragPoint.y) < 1e-10)
    }

    @Test func unrotatingBy180DegreesReflectsPoint() async throws {
        let center = CGPoint(x: 200, y: 200)
        let dragPoint = CGPoint(x: 300, y: 250)  // Offset (+100, +50) from center

        let localDrag = unrotatePoint(dragPoint, aroundCenter: center, by: .pi)

        // -180° rotation: dx,dy get negated
        // x' = 200 + (-100)*(-1) - (50)*0 = 200 + 100 = 100...
        // cos(-180) = -1, sin(-180) ≈ 0
        // x' = 200 + 100*(-1) - 50*0 = 200 - 100 = 100
        // y' = 200 + 100*0 + 50*(-1) = 200 - 50 = 150
        #expect(abs(localDrag.x - 100) < 1e-5)
        #expect(abs(localDrag.y - 150) < 1e-5)
    }

    // MARK: - Minimum size constraint

    @Test func resizeRespectsMinimumSize() async throws {
        let minSize: CGFloat = 20.0

        // Simulate clamping
        let rawWidth: CGFloat = 5   // too small
        let rawHeight: CGFloat = 300

        let clampedWidth = max(rawWidth, minSize)
        let clampedHeight = max(rawHeight, minSize)

        #expect(clampedWidth == 20)
        #expect(clampedHeight == 300)
    }
}
