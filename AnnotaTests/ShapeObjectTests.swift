//
//  ShapeObjectTests.swift
//  AnnotaTests
//
//  Unit tests for ShapeObject: contains(), hitTest(), rotation, and custom SVG paths.
//

import Testing
import SwiftUI
import CoreGraphics
@testable import AnotarCanvas

@MainActor
struct ShapeObjectTests {

    // MARK: - Helpers

    private func makeShape(
        svgPath: String,
        toolId: String,
        x: CGFloat = 0, y: CGFloat = 0,
        width: CGFloat = 100, height: CGFloat = 100,
        rotation: CGFloat = 0
    ) -> ShapeObject {
        ShapeObject(
            position: CGPoint(x: x, y: y),
            size: CGSize(width: width, height: height),
            svgPath: svgPath,
            toolId: toolId,
            color: .black,
            rotation: rotation
        )
    }

    // Built-in shape SVG paths
    private let rectanglePath = "M 0,0 L 100,0 L 100,100 L 0,100 Z"
    private let ovalPath = """
        M 50 0 C 77.6 0 100 22.4 100 50
        C 100 77.6 77.6 100 50 100
        C 22.4 100 0 77.6 0 50
        C 0 22.4 22.4 0 50 0 Z
        """
    private let trianglePath = "M 50,0 L 100,100 L 0,100 Z"
    private let diamondPath = "M 50,0 L 100,50 L 50,100 L 0,50 Z"

    // MARK: - contains() — rectangle

    @Test func rectangleContainsCenterPoint() async throws {
        let shape = makeShape(svgPath: rectanglePath, toolId: "rectangle", x: 0, y: 0, width: 100, height: 100)
        // Center of the bounding box must be inside
        #expect(shape.contains(CGPoint(x: 50, y: 50)))
    }

    @Test func rectangleDoesNotContainOutsidePoint() async throws {
        let shape = makeShape(svgPath: rectanglePath, toolId: "rectangle", x: 0, y: 0, width: 100, height: 100)
        // Clearly outside
        #expect(!shape.contains(CGPoint(x: 200, y: 200)))
    }

    // MARK: - contains() — oval

    @Test func ovalContainsCenterPoint() async throws {
        let shape = makeShape(svgPath: ovalPath, toolId: "oval", x: 0, y: 0, width: 100, height: 100)
        // Center of the ellipse must be inside
        #expect(shape.contains(CGPoint(x: 50, y: 50)))
    }

    @Test func ovalDoesNotContainCornerOfBoundingBox() async throws {
        let shape = makeShape(svgPath: ovalPath, toolId: "oval", x: 0, y: 0, width: 100, height: 100)
        // Corners of bounding box are outside the inscribed ellipse
        #expect(!shape.contains(CGPoint(x: 1, y: 1)))
        #expect(!shape.contains(CGPoint(x: 99, y: 1)))
        #expect(!shape.contains(CGPoint(x: 1, y: 99)))
        #expect(!shape.contains(CGPoint(x: 99, y: 99)))
    }

    // MARK: - contains() — triangle

    @Test func triangleContainsCentroid() async throws {
        // Triangle SVG: M 50 0 L 100 100 L 0 100 Z — centroid at (50, 66.7)
        let shape = makeShape(svgPath: trianglePath, toolId: "triangle", x: 0, y: 0, width: 100, height: 100)
        #expect(shape.contains(CGPoint(x: 50, y: 67)))
    }

    @Test func triangleDoesNotContainBottomLeftCornerOfBoundingBox() async throws {
        // The triangle has vertices at (50,0), (100,100), (0,100).
        // At y=50 the left edge is at x=25. A point at (2, 50) is clearly outside.
        let shape = makeShape(svgPath: trianglePath, toolId: "triangle", x: 0, y: 0, width: 100, height: 100)
        #expect(!shape.contains(CGPoint(x: 2, y: 50)))
    }

    // MARK: - hitTest() — corners always on bounding box

    @Test func hitTestCornerDetectedForRectangle() async throws {
        let shape = makeShape(svgPath: rectanglePath, toolId: "rectangle", x: 0, y: 0, width: 100, height: 100)
        let threshold: CGFloat = 8
        // Top-left corner of bounding box
        let result = shape.hitTest(CGPoint(x: 0, y: 0), threshold: threshold)
        if case .corner(let c) = result {
            #expect(c == .topLeft)
        } else {
            #expect(Bool(false), "Expected .corner(.topLeft), got \(String(describing: result))")
        }
    }

    @Test func hitTestCornerDetectedForOval() async throws {
        // Oval corner handles are on the bounding box corners, not the ellipse edge
        let shape = makeShape(svgPath: ovalPath, toolId: "oval", x: 0, y: 0, width: 100, height: 100)
        let threshold: CGFloat = 8
        let result = shape.hitTest(CGPoint(x: 100, y: 100), threshold: threshold)
        if case .corner(let c) = result {
            #expect(c == .bottomRight)
        } else {
            #expect(Bool(false), "Expected .corner(.bottomRight), got \(String(describing: result))")
        }
    }

    @Test func hitTestCornerDetectedForTriangle() async throws {
        let shape = makeShape(svgPath: trianglePath, toolId: "triangle", x: 0, y: 0, width: 100, height: 100)
        let threshold: CGFloat = 8
        let result = shape.hitTest(CGPoint(x: 100, y: 0), threshold: threshold)
        if case .corner(let c) = result {
            #expect(c == .topRight)
        } else {
            #expect(Bool(false), "Expected .corner(.topRight), got \(String(describing: result))")
        }
    }

    // MARK: - hitTest() — edge/body/nil detection

    @Test func hitTestEdgeOnOvalCurveNotBoundingBoxEdge() async throws {
        // For an oval, the right edge of the ellipse at midpoint is at (100, 50).
        // That point is on the shape boundary — hitTest should return .edge, not nil.
        let shape = makeShape(svgPath: ovalPath, toolId: "oval", x: 0, y: 0, width: 100, height: 100)
        let threshold: CGFloat = 8
        let result = shape.hitTest(CGPoint(x: 100, y: 50), threshold: threshold)
        // Should be edge or corner (it's on the shape boundary)
        #expect(result != nil)
        // Should NOT be body (it's on the edge)
        if case .body = result {
            #expect(Bool(false), "Expected edge/corner, not body")
        }
    }

    @Test func hitTestBodyInsideOval() async throws {
        let shape = makeShape(svgPath: ovalPath, toolId: "oval", x: 0, y: 0, width: 100, height: 100)
        let threshold: CGFloat = 4
        // Center of the oval is firmly inside
        let result = shape.hitTest(CGPoint(x: 50, y: 50), threshold: threshold)
        if case .body = result {
            // Correct
        } else {
            #expect(Bool(false), "Expected .body, got \(String(describing: result))")
        }
    }

    @Test func hitTestNilOutsideOvalBoundingBox() async throws {
        let shape = makeShape(svgPath: ovalPath, toolId: "oval", x: 0, y: 0, width: 100, height: 100)
        let threshold: CGFloat = 4
        // Point far outside the bounding box
        let result = shape.hitTest(CGPoint(x: 200, y: 200), threshold: threshold)
        #expect(result == nil)
    }

    // MARK: - Rotation

    @Test func rotatedShapeContainsPointInRotatedSpace() async throws {
        // A 100×20 horizontal rectangle rotated 90° becomes effectively 20×100.
        // The original top-right corner area (90, 5) in unrotated space is inside,
        // but after 90° CCW rotation the shape extends vertically.
        // Point at canvas (55, 90): in local space (after -90° transform around center (50,10))
        // this maps back inside the original bounds.
        let shape = makeShape(svgPath: rectanglePath, toolId: "rectangle", x: 0, y: 0, width: 100, height: 20, rotation: .pi / 2)
        // Center is at (50, 10). After 90° rotation, the long axis runs vertically.
        // A point at (50, 50) in canvas space: local coords → inside the 100×20 rect.
        let center = CGPoint(x: 50, y: 10)
        // Canvas point offset: (0, 40) from center → rotated -90° → (40, 0) from center → (90, 10) local
        // (90, 10) is inside [0..100, 0..20] ✓
        let canvasPoint = CGPoint(x: center.x, y: center.y + 40)
        #expect(shape.contains(canvasPoint))
    }

    @Test func rotatedShapeDoesNotContainSamePointInUnrotatedSpace() async throws {
        // Same setup as above but unrotated: the 100×20 rect does NOT contain (50, 50)
        // since y=50 is outside [0..20].
        let shape = makeShape(svgPath: rectanglePath, toolId: "rectangle", x: 0, y: 0, width: 100, height: 20, rotation: 0)
        #expect(!shape.contains(CGPoint(x: 50, y: 50)))
    }

    // MARK: - Custom SVG path

    @Test func customSVGPathContainsExpectedPoints() async throws {
        // A diamond shape: M 50 0 L 100 50 L 50 100 L 0 50 Z
        // The center (50, 50) is inside the diamond.
        let shape = makeShape(svgPath: diamondPath, toolId: "custom-diamond", x: 0, y: 0, width: 100, height: 100)
        #expect(shape.contains(CGPoint(x: 50, y: 50)))
        // Also a point close to center should be inside
        #expect(shape.contains(CGPoint(x: 50, y: 40)))
    }

    @Test func customSVGPathRejectsPointsOutsideShape() async throws {
        // Diamond: corners of bounding box are outside the diamond
        let shape = makeShape(svgPath: diamondPath, toolId: "custom-diamond", x: 0, y: 0, width: 100, height: 100)
        // Top-left corner (2, 2) is outside the diamond
        #expect(!shape.contains(CGPoint(x: 2, y: 2)))
        // Top-right corner (98, 2) is outside
        #expect(!shape.contains(CGPoint(x: 98, y: 2)))
    }
}
