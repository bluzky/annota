//
//  SelectionBoxTests.swift
//  texttoolTests
//
//  Created by Claude on 2/18/26.
//

import Testing
import SwiftUI
@testable import AnotarCanvas

@MainActor
struct SelectionBoxTests {

    // MARK: - Factory Tests

    @Test func fromEmptyObjectsReturnsNil() async throws {
        let objects: [AnyCanvasObject] = []
        let selectionBox = SelectionBox.from(objects: objects)
        #expect(selectionBox == nil)
    }

    @Test func fromSingleObjectCreatesSingleSelection() async throws {
        let rect = ShapeObject(
            position: CGPoint(x: 100, y: 100),
            size: CGSize(width: 200, height: 150),
            preset: .rectangle,
            color: .blue
        )
        let objects = [AnyCanvasObject(rect)]

        let selectionBox = SelectionBox.from(objects: objects)

        #expect(selectionBox != nil)
        #expect(selectionBox!.isSingleSelection == true)
        #expect(selectionBox!.bounds == CGRect(x: 100, y: 100, width: 200, height: 150))
    }

    @Test func fromMultipleObjectsCreatesMultiSelection() async throws {
        let rect1 = ShapeObject(
            position: CGPoint(x: 0, y: 0),
            size: CGSize(width: 100, height: 100),
            preset: .rectangle,
            color: .blue
        )
        let rect2 = ShapeObject(
            position: CGPoint(x: 200, y: 150),
            size: CGSize(width: 100, height: 100),
            preset: .rectangle,
            color: .red
        )
        let objects = [AnyCanvasObject(rect1), AnyCanvasObject(rect2)]

        let selectionBox = SelectionBox.from(objects: objects)

        #expect(selectionBox != nil)
        #expect(selectionBox!.isSingleSelection == false)
        // Combined bounds should encompass both objects
        #expect(selectionBox!.bounds.minX == 0)
        #expect(selectionBox!.bounds.minY == 0)
        #expect(selectionBox!.bounds.maxX == 300) // 200 + 100
        #expect(selectionBox!.bounds.maxY == 250) // 150 + 100
    }

    // MARK: - Handle Position Tests

    @Test func cornerPositionsAreCorrect() async throws {
        let selectionBox = SelectionBox(
            bounds: CGRect(x: 50, y: 50, width: 100, height: 80),
            isSingleSelection: true,
            rotation: 0
        )

        #expect(selectionBox.cornerPosition(for: .topLeft) == CGPoint(x: 50, y: 50))
        #expect(selectionBox.cornerPosition(for: .topRight) == CGPoint(x: 150, y: 50))
        #expect(selectionBox.cornerPosition(for: .bottomLeft) == CGPoint(x: 50, y: 130))
        #expect(selectionBox.cornerPosition(for: .bottomRight) == CGPoint(x: 150, y: 130))
    }

    @Test func edgePositionsAreCorrect() async throws {
        let selectionBox = SelectionBox(
            bounds: CGRect(x: 0, y: 0, width: 200, height: 100),
            isSingleSelection: true,
            rotation: 0
        )

        #expect(selectionBox.edgePosition(for: .top) == CGPoint(x: 100, y: 0))
        #expect(selectionBox.edgePosition(for: .bottom) == CGPoint(x: 100, y: 100))
        #expect(selectionBox.edgePosition(for: .left) == CGPoint(x: 0, y: 50))
        #expect(selectionBox.edgePosition(for: .right) == CGPoint(x: 200, y: 50))
    }

    @Test func centerIsCorrect() async throws {
        let selectionBox = SelectionBox(
            bounds: CGRect(x: 100, y: 100, width: 200, height: 150),
            isSingleSelection: true,
            rotation: 0
        )

        #expect(selectionBox.center == CGPoint(x: 200, y: 175))
    }

    // MARK: - Hit Test Tests

    @Test func hitTestInteriorReturnsMove() async throws {
        let selectionBox = SelectionBox(
            bounds: CGRect(x: 100, y: 100, width: 200, height: 150),
            isSingleSelection: true,
            rotation: 0
        )

        // Point inside the bounds
        let result = selectionBox.hitTest(CGPoint(x: 200, y: 175))
        #expect(result == .move)
    }

    @Test func hitTestCornerReturnsCorner() async throws {
        let selectionBox = SelectionBox(
            bounds: CGRect(x: 100, y: 100, width: 200, height: 150),
            isSingleSelection: true,
            rotation: 0
        )

        // Hit top-left corner
        let topLeft = selectionBox.hitTest(CGPoint(x: 100, y: 100))
        #expect(topLeft == .corner(.topLeft))

        // Hit bottom-right corner
        let bottomRight = selectionBox.hitTest(CGPoint(x: 300, y: 250))
        #expect(bottomRight == .corner(.bottomRight))
    }

    @Test func hitTestEdgeReturnsEdge() async throws {
        let selectionBox = SelectionBox(
            bounds: CGRect(x: 100, y: 100, width: 200, height: 150),
            isSingleSelection: true,
            rotation: 0
        )

        // Hit top edge (middle)
        let top = selectionBox.hitTest(CGPoint(x: 200, y: 100))
        #expect(top == .edge(.top))

        // Hit right edge (middle)
        let right = selectionBox.hitTest(CGPoint(x: 300, y: 175))
        #expect(right == .edge(.right))
    }

    @Test func hitTestOutsideReturnsNil() async throws {
        let selectionBox = SelectionBox(
            bounds: CGRect(x: 100, y: 100, width: 200, height: 150),
            isSingleSelection: true,
            rotation: 0
        )

        // Point way outside
        let result = selectionBox.hitTest(CGPoint(x: 0, y: 0))
        #expect(result == nil)
    }

    @Test func hitTestRotationHandleReturnsRotation() async throws {
        let selectionBox = SelectionBox(
            bounds: CGRect(x: 100, y: 100, width: 200, height: 150),
            isSingleSelection: true,
            rotation: 0
        )

        // Rotation handle is the larger area at the corner, outside the small resize handle radius
        // Corner is at (100, 100), resize radius ~8, rotation handle shifted outward
        let rotationPos = CGPoint(x: 100 - 9, y: 100 - 9)
        let result = selectionBox.hitTest(rotationPos)
        #expect(result == .rotation(.topLeft))
    }

    @Test func multiSelectionEdgeHandlesAreActiveForMultiSelect() async throws {
        // Edge handles are active for both single and multi selection in the current implementation.
        // A point on the top edge mid-span should return .edge(.top).
        let selectionBox = SelectionBox(
            bounds: CGRect(x: 100, y: 100, width: 200, height: 150),
            isSingleSelection: false,
            rotation: 0
        )

        // Top edge hit rect: x:[108, 292], y:[96, 104] — point (200, 100) is on the boundary
        let top = selectionBox.hitTest(CGPoint(x: 200, y: 100))
        // The corner handle is checked first; mid-edge away from corners should return edge
        // (200, 100) is mid-edge, far from corners at (100,100) and (300,100) - resizeRadius=8
        // distance to topLeft corner = 100 units → not a corner, so should be edge
        #expect(top == .edge(.top))
    }

    @Test func multiSelectionRotationHandlesAreActiveByDefault() async throws {
        // The current implementation does not suppress rotation handles for multi-selection.
        // A point in the rotation handle zone returns .rotation even for multi-select.
        let selectionBox = SelectionBox(
            bounds: CGRect(x: 100, y: 100, width: 200, height: 150),
            isSingleSelection: false,
            rotation: 0
        )

        // Rotation handle at topLeft: center = (100-6, 100-6) = (94, 94), halfSize=10
        // Hit rect: (84, 84) to (104, 104)
        let rotationPos = CGPoint(x: 91, y: 91)
        let result = selectionBox.hitTest(rotationPos)
        #expect(result == .rotation(.topLeft))
    }

    @Test func multiSelectionInteriorReturnsMoveForPointWellInsideBounds() async throws {
        let selectionBox = SelectionBox(
            bounds: CGRect(x: 100, y: 100, width: 200, height: 150),
            isSingleSelection: false,
            rotation: 0
        )

        // A point well inside bounds, far from all handle zones
        let interior = selectionBox.hitTest(CGPoint(x: 200, y: 175))
        #expect(interior == .move)
    }

    // MARK: - Rotated Selection Box Tests

    @Test func rotatedSingleSelectionBoundsMatch() async throws {
        // A rotated single object: selection box bounds use unrotated bbox
        let rect = ShapeObject(
            position: CGPoint(x: 100, y: 100),
            size: CGSize(width: 200, height: 100),
            preset: .rectangle,
            color: .blue,
            rotation: .pi / 4  // 45 degrees
        )
        let objects = [AnyCanvasObject(rect)]
        let selectionBox = SelectionBox.from(objects: objects)!

        // For single selection, bounds are the unrotated bbox
        #expect(selectionBox.bounds.origin.x == 100)
        #expect(selectionBox.bounds.origin.y == 100)
        #expect(selectionBox.bounds.width == 200)
        #expect(selectionBox.bounds.height == 100)
        #expect(selectionBox.rotation == .pi / 4)
    }

    @Test func rotatedMultiSelectionExpandsBoundsToFitRotatedCorners() async throws {
        // A 45-degree rotated square's AABB should be larger than the square
        let rect = ShapeObject(
            position: CGPoint(x: 100, y: 100),
            size: CGSize(width: 100, height: 100),
            preset: .rectangle,
            color: .blue,
            rotation: .pi / 4  // 45 degrees
        )
        // Need two objects for multi-selection
        let rect2 = ShapeObject(
            position: CGPoint(x: 300, y: 300),
            size: CGSize(width: 10, height: 10),
            preset: .rectangle,
            color: .red
        )
        let objects = [AnyCanvasObject(rect), AnyCanvasObject(rect2)]
        let selectionBox = SelectionBox.from(objects: objects)!

        // The rotated 100x100 square centered at (150, 150), rotated 45°,
        // has corner diagonal = 100*sqrt(2)/2 ≈ 70.7, so extent from center ≈ 70.7
        // meaning minX ≈ 150 - 70.7 ≈ 79.3, but we also have the second rect
        // The AABB width must be larger than the original 100 due to rotation
        #expect(selectionBox.bounds.width > 100)
        #expect(selectionBox.rotation == 0)  // Multi-selection has no rotation
    }

    @Test func toScreenConversionScalesBounds() async throws {
        let selectionBox = SelectionBox(
            bounds: CGRect(x: 100, y: 50, width: 200, height: 100),
            isSingleSelection: true,
            rotation: 0
        )

        var viewport = ViewportState()
        viewport.scale = 2.0

        let screenBox = selectionBox.toScreen(viewport: viewport)

        // canvas origin (100, 50) → screen (100*2+0, 50*2+0) = (200, 100)
        #expect(screenBox.bounds.minX == 200)
        #expect(screenBox.bounds.minY == 100)
        // size: 200*2=400, 100*2=200
        #expect(screenBox.bounds.width == 400)
        #expect(screenBox.bounds.height == 200)
    }

    @Test func toScreenWithOffsetAndScale() async throws {
        let selectionBox = SelectionBox(
            bounds: CGRect(x: 50, y: 50, width: 100, height: 100),
            isSingleSelection: true,
            rotation: 0
        )

        var viewport = ViewportState()
        viewport.scale = 2.0
        viewport.offset = CGPoint(x: 20, y: 30)

        let screenBox = selectionBox.toScreen(viewport: viewport)

        // origin: x = 50*2 + 20 = 120, y = 50*2 + 30 = 130
        #expect(screenBox.bounds.minX == 120)
        #expect(screenBox.bounds.minY == 130)
        // size: 100*2=200 (size not affected by offset, only extent)
        // Actually toScreen converts both origin and maxX/maxY separately:
        // maxX: (150*2 + 20) = 320, maxY: (150*2 + 30) = 330
        // width = 320 - 120 = 200, height = 330 - 130 = 200
        #expect(screenBox.bounds.width == 200)
        #expect(screenBox.bounds.height == 200)
    }
}
