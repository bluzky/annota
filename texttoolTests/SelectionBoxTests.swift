//
//  SelectionBoxTests.swift
//  texttoolTests
//
//  Created by Claude on 2/18/26.
//

import Testing
import SwiftUI
@testable import texttool

struct SelectionBoxTests {

    // MARK: - Factory Tests

    @Test func fromEmptyObjectsReturnsNil() async throws {
        let objects: [AnyCanvasObject] = []
        let selectionBox = SelectionBox.from(objects: objects)
        #expect(selectionBox == nil)
    }

    @Test func fromSingleObjectCreatesSingleSelection() async throws {
        let rect = RectangleObject(
            position: CGPoint(x: 100, y: 100),
            size: CGSize(width: 200, height: 150),
            color: .blue
        )
        let objects = [AnyCanvasObject(rect)]

        let selectionBox = SelectionBox.from(objects: objects)

        #expect(selectionBox != nil)
        #expect(selectionBox!.isSingleSelection == true)
        #expect(selectionBox!.bounds == CGRect(x: 100, y: 100, width: 200, height: 150))
    }

    @Test func fromMultipleObjectsCreatesMultiSelection() async throws {
        let rect1 = RectangleObject(
            position: CGPoint(x: 0, y: 0),
            size: CGSize(width: 100, height: 100),
            color: .blue
        )
        let rect2 = RectangleObject(
            position: CGPoint(x: 200, y: 150),
            size: CGSize(width: 100, height: 100),
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
            individualBounds: [:],
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
            individualBounds: [:],
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
            individualBounds: [:],
            isSingleSelection: true,
            rotation: 0
        )

        #expect(selectionBox.center == CGPoint(x: 200, y: 175))
    }

    // MARK: - Hit Test Tests

    @Test func hitTestInteriorReturnsMove() async throws {
        let selectionBox = SelectionBox(
            bounds: CGRect(x: 100, y: 100, width: 200, height: 150),
            individualBounds: [:],
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
            individualBounds: [:],
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
            individualBounds: [:],
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
            individualBounds: [:],
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
            individualBounds: [:],
            isSingleSelection: true,
            rotation: 0
        )

        // Rotation handle is the larger area at the corner, outside the small resize handle radius
        // Corner is at (100, 100), resize radius ~8, rotation radius ~10
        let rotationPos = CGPoint(x: 100 - 9, y: 100 - 9)
        let result = selectionBox.hitTest(rotationPos)
        #expect(result == .rotation(.topLeft))
    }

    @Test func multiSelectionDoesNotShowEdgeHandles() async throws {
        let selectionBox = SelectionBox(
            bounds: CGRect(x: 100, y: 100, width: 200, height: 150),
            individualBounds: [:],
            isSingleSelection: false,  // Multi-selection
            rotation: 0
        )

        // Edge hit test should return move for multi-selection
        // (edges are not active handles in multi-selection)
        let top = selectionBox.hitTest(CGPoint(x: 200, y: 100))
        // Corner takes precedence at edges, but mid-edge should return move
        // Actually, corners are still active in multi-selection
        // Let's test a point that's on the edge but not corner
        let midTop = selectionBox.hitTest(CGPoint(x: 200, y: 102)) // Slightly inside
        #expect(midTop == .move)
    }

    @Test func multiSelectionDoesNotShowRotationHandles() async throws {
        let selectionBox = SelectionBox(
            bounds: CGRect(x: 100, y: 100, width: 200, height: 150),
            individualBounds: [:],
            isSingleSelection: false,  // Multi-selection
            rotation: 0
        )

        // Point in the rotation area but outside resize radius
        let rotationPos = CGPoint(x: 100 - 9, y: 100 - 9)
        let result = selectionBox.hitTest(rotationPos)
        // Should not return rotation for multi-selection
        #expect(result == nil)
    }
}
